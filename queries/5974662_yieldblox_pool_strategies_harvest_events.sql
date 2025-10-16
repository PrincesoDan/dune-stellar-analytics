-- Query: Yieldblox Pool Strategies (Blend) - Harvest Events
-- Description: Shows all harvest events from BlendStrategy contracts with amount, from address, and price_per_share
-- Includes strategies for: USDC, EURC, and XLM

WITH strategy_contracts AS (
    SELECT contract_id, asset
    FROM (VALUES
        ('CDB2WMKQQNVZMEBY7Q7GZ5C7E7IAFSNMZ7GGVD6WKTCEWK7XOIAVZSAP', 'USDC'),
        ('CA33NXYN7H3EBDSA3U2FPSULGJTTL3FQRHD2ADAAPTKS3FUJOE73735A', 'EURC'),
        ('CBDOIGFO2QOOZTWQZ7AFPH5JOUS2SBN5CTTXR665NHV6GOCM6OUGI5KP', 'XLM'),
        ('CDPWNUW7UMCSVO36VAJSQHQECISPJLCVPDASKHRC5SEROAAZDUQ5DG2Z', 'XLM')
    ) AS t(contract_id, asset)
),

base AS (
    SELECT
        he.contract_id,
        he.closed_at,
        DATE_TRUNC('hour', he.closed_at) AS closed_at_hour,
        he.transaction_hash AS tx_hash,
        he.transaction_id AS tx_id,
        he.topics_decoded,
        CAST(json_extract(he.data_decoded,'$.map') AS array(json)) AS map_elems
    FROM stellar.history_contract_events he
    WHERE he.contract_id IN (SELECT contract_id FROM strategy_contracts)
      AND he.topics_decoded LIKE '%BlendStrategy%'
      AND he.topics_decoded LIKE '%harvest%'
),

-- Extract 'from' address
from_addr AS (
    SELECT
        b.tx_hash,
        MAX(json_extract_scalar(e,'$.val.address')) AS from_address
    FROM base b
    CROSS JOIN UNNEST(b.map_elems) AS t(e)
    WHERE json_extract_scalar(e,'$.key.symbol') = 'from'
    GROUP BY b.tx_hash
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
    b.closed_at,
    b.closed_at_hour,
    sc.asset,
    b.contract_id,
    b.tx_hash,
    b.tx_id,
    f.from_address AS "from",
    a.amount,
    p.price_per_share,
    -- Calculate amount in standard units (dividing by 1e7 for Stellar 7 decimal places)
    a.amount AS amount_raw,
    -- Calculate price per share in standard units
    p.price_per_share AS price_per_share_raw
FROM base b
LEFT JOIN strategy_contracts sc ON sc.contract_id = b.contract_id
LEFT JOIN from_addr f ON f.tx_hash = b.tx_hash
LEFT JOIN amount_data a ON a.tx_hash = b.tx_hash
LEFT JOIN price_data p ON p.tx_hash = b.tx_hash
ORDER BY b.closed_at DESC;
