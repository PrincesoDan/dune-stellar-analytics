-- Query: Strategies - Harvest Events
-- Description: Shows all harvest events from YieldBlox strategy contracts
-- Columns:
--   - hour: Timestamp rounded to hour of when the harvest event occurred
--   - strategy_address: Contract address of the strategy
--   - asset: Asset/token (USDC, EURC, XLM)
--   - amount: Total amount harvested
--   - price_per_share: Value per share at the time of harvest
--   - hash: Transaction hash
--   - closed_at: Exact timestamp of the event
-- Source: https://dune.com/queries/5974662
-- Uses summary_strategies table (query_6014850) to get YieldBlox strategy addresses

WITH strategy_contracts AS (
    -- Get YieldBlox strategy contracts from summary_strategies table
    SELECT
        strategy_address AS contract_id,
        asset_token AS asset,
        strategy_name
    FROM query_6014850
    WHERE strategy_name LIKE '%yieldblox_strategy%'
      AND asset_token IN ('USDC', 'EURC', 'XLM')
),

base AS (
    SELECT
        he.contract_id,
        he.closed_at,
        DATE_TRUNC('hour', he.closed_at) AS closed_at_hour,
        he.transaction_hash AS tx_hash,
        he.topics_decoded,
        CAST(json_extract(he.data_decoded,'$.map') AS array(json)) AS map_elems
    FROM stellar.history_contract_events he
    WHERE he.contract_id IN (SELECT contract_id FROM strategy_contracts)
      AND he.topics_decoded LIKE '%BlendStrategy%'
      AND he.topics_decoded LIKE '%harvest%'
),

-- Extract 'amount' (i128)
amount_data AS (
    SELECT
        b.tx_hash,
        MAX(
            TRY(
                CASE
                    WHEN json_extract_scalar(e, '$.val.i128.hi') IS NOT NULL THEN
                        CAST(
                            CAST(json_extract_scalar(e, '$.val.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
                          + CAST(json_extract_scalar(e, '$.val.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                        AS DECIMAL(38,7))
                    WHEN json_extract_scalar(e, '$.val.i128') IS NOT NULL THEN
                        CAST(
                            CAST(json_extract_scalar(e, '$.val.i128') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                        AS DECIMAL(38,7))
                    ELSE NULL
                END
            )
        ) AS amount
    FROM base b
    CROSS JOIN UNNEST(b.map_elems) AS t(e)
    WHERE json_extract_scalar(e,'$.key.symbol') = 'amount'
    GROUP BY b.tx_hash
),

-- Extract 'price_per_share' (i128)
price_data AS (
    SELECT
        b.tx_hash,
        MAX(
            TRY(
                CASE
                    WHEN json_extract_scalar(e, '$.val.i128.hi') IS NOT NULL THEN
                        CAST(
                            CAST(json_extract_scalar(e, '$.val.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
                          + CAST(json_extract_scalar(e, '$.val.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                        AS DECIMAL(38,7))
                    WHEN json_extract_scalar(e, '$.val.i128') IS NOT NULL THEN
                        CAST(
                            CAST(json_extract_scalar(e, '$.val.i128') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                        AS DECIMAL(38,7))
                    ELSE NULL
                END
            )
        ) AS price_per_share
    FROM base b
    CROSS JOIN UNNEST(b.map_elems) AS t(e)
    WHERE json_extract_scalar(e,'$.key.symbol') = 'price_per_share'
    GROUP BY b.tx_hash
)

-- Final assembly
SELECT
    b.closed_at_hour AS hour,
    b.contract_id AS strategy_address,
    sc.asset,
    a.amount,
    p.price_per_share,
    b.tx_hash AS hash,
    b.closed_at
FROM base b
LEFT JOIN strategy_contracts sc ON sc.contract_id = b.contract_id
LEFT JOIN amount_data a ON a.tx_hash = b.tx_hash
LEFT JOIN price_data p ON p.tx_hash = b.tx_hash
ORDER BY b.closed_at DESC;
