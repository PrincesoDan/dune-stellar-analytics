-- Query: vaults_locked_fees
-- Description: **DeFindex Vaults - Locked Fees Analysis**  
The key metrics "locked_fee," "gains_or_losses," and "prev_balance" are crucial for assessing the financial health and performance of DeFindex Vaults, providing insights into fee accumulation, profitability, and historical balance trends for strategic decision-making.
-- Source: https://dune.com/queries/5975332
-- already part of a query repo

-- Query: DeFindex Vaults - Locked Fees from Report Data
-- Description: Extracts locked_fee from persistent contract data (Report key)
-- Data structure: Key = ["Report"sym, <strategy_address>], Value = {gains_or_losses, locked_fee, prev_balance}
-- Source: stellar.contract_data

WITH vault_list AS (
    SELECT
        vault,
        vault_name,
        asset,
        asset_code
    FROM query_5782251
),

-- Get all contract data for vaults with "Report" keys
report_data AS (
    SELECT
        cd.contract_id AS vault,
        cd.closed_at,
        cd.ledger_sequence,
        cd.key_decoded,
        cd.val_decoded,
        cd.contract_key_type,
        cd.last_modified_ledger
    FROM stellar.contract_data cd
    WHERE cd.contract_id IN (SELECT vault FROM vault_list)
      AND cd.key_decoded LIKE '%Report%'
      AND cd.deleted = false
),

-- Parse the key to extract strategy address
parsed_keys AS (
    SELECT
        r.vault,
        r.closed_at,
        r.ledger_sequence,
        r.key_decoded,
        r.val_decoded,
        -- Parse key structure to extract strategy address
        -- Key format: ["Report", "<strategy_address>"]
        CAST(json_extract(CAST(JSON_PARSE(r.key_decoded) AS JSON), '$.vec') AS array(json)) AS key_vec
    FROM report_data r
),

strategy_extracted AS (
    SELECT
        pk.vault,
        pk.closed_at,
        pk.ledger_sequence,
        pk.val_decoded,
        -- Extract strategy address from second element of key vector
        json_extract_scalar(
            CAST(json_extract(CAST(JSON_PARSE(pk.key_decoded) AS JSON), '$.vec[1]') AS json),
            '$.address'
        ) AS strategy_address
    FROM parsed_keys pk
),

-- Parse the value to extract locked_fee, gains_or_losses, and prev_balance
parsed_values AS (
    SELECT
        se.vault,
        se.closed_at,
        se.ledger_sequence,
        se.strategy_address,
        -- Parse val_decoded as JSON map
        CAST(json_extract(CAST(JSON_PARSE(se.val_decoded) AS JSON), '$.map') AS array(json)) AS val_map
    FROM strategy_extracted se
),

-- Extract individual fields from the map
extracted_fields AS (
    SELECT
        pv.vault,
        pv.closed_at,
        pv.ledger_sequence,
        pv.strategy_address,
        pv.val_map,
        -- Extract locked_fee
        MAX(CASE
            WHEN json_extract_scalar(field, '$.key.symbol') = 'locked_fee' THEN
                TRY(
                    CASE
                        WHEN json_extract_scalar(field, '$.val.i128.hi') IS NOT NULL THEN
                            CAST(
                                CAST(json_extract_scalar(field, '$.val.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
                              + CAST(json_extract_scalar(field, '$.val.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                            AS DECIMAL(38,7))
                        WHEN json_extract_scalar(field, '$.val.i128') IS NOT NULL THEN
                            CAST(
                                CAST(json_extract_scalar(field, '$.val.i128') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                            AS DECIMAL(38,7))
                        ELSE NULL
                    END
                )
        END) AS locked_fee,
        -- Extract gains_or_losses
        MAX(CASE
            WHEN json_extract_scalar(field, '$.key.symbol') = 'gains_or_losses' THEN
                TRY(
                    CASE
                        WHEN json_extract_scalar(field, '$.val.i128.hi') IS NOT NULL THEN
                            CAST(
                                CAST(json_extract_scalar(field, '$.val.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
                              + CAST(json_extract_scalar(field, '$.val.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                            AS DECIMAL(38,7))
                        WHEN json_extract_scalar(field, '$.val.i128') IS NOT NULL THEN
                            CAST(
                                CAST(json_extract_scalar(field, '$.val.i128') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                            AS DECIMAL(38,7))
                        ELSE NULL
                    END
                )
        END) AS gains_or_losses,
        -- Extract prev_balance
        MAX(CASE
            WHEN json_extract_scalar(field, '$.key.symbol') = 'prev_balance' THEN
                TRY(
                    CASE
                        WHEN json_extract_scalar(field, '$.val.i128.hi') IS NOT NULL THEN
                            CAST(
                                CAST(json_extract_scalar(field, '$.val.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
                              + CAST(json_extract_scalar(field, '$.val.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                            AS DECIMAL(38,7))
                        WHEN json_extract_scalar(field, '$.val.i128') IS NOT NULL THEN
                            CAST(
                                CAST(json_extract_scalar(field, '$.val.i128') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                            AS DECIMAL(38,7))
                        ELSE NULL
                    END
                )
        END) AS prev_balance
    FROM parsed_values pv
    CROSS JOIN UNNEST(pv.val_map) AS t(field)
    GROUP BY pv.vault, pv.closed_at, pv.ledger_sequence, pv.strategy_address, pv.val_map
),

-- Rank records to get the latest locked_fee per vault
ranked_records AS (
    SELECT
        ef.closed_at,
        ef.ledger_sequence,
        ef.vault,
        ef.strategy_address,
        ef.locked_fee,
        ef.gains_or_losses,
        ef.prev_balance,
        ROW_NUMBER() OVER (
            PARTITION BY ef.vault, ef.strategy_address
            ORDER BY ef.closed_at DESC, ef.ledger_sequence DESC
        ) AS rn
    FROM extracted_fields ef
)

-- Final assembly with vault information - showing only the latest record per vault+strategy
SELECT
    rr.closed_at,
    rr.ledger_sequence,
    rr.vault,
    vl.vault_name,
    vl.asset,
    vl.asset_code,
    rr.strategy_address,
    rr.locked_fee,
    rr.gains_or_losses,
    rr.prev_balance
FROM ranked_records rr
LEFT JOIN vault_list vl ON vl.vault = rr.vault
WHERE rr.rn = 1
ORDER BY rr.closed_at DESC, rr.vault, rr.strategy_address;
