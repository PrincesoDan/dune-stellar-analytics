-- Query: DeFindex Vaults Events
-- Description: N/A
-- Source: https://dune.com/queries/5900680
-- already part of a query repo

WITH vault_to_token AS (
    SELECT
        vault,
        asset,
        asset_code,
        vault_name
    FROM query_5782251
),

base AS (
    SELECT
        he.contract_id AS vault,
        he.closed_at,
        DATE_TRUNC('hour', he.closed_at) AS closed_at_hour,
        he.transaction_hash AS tx_hash,
        he.transaction_id AS tx_id,
        CASE
            WHEN he.topics_decoded LIKE '%withdraw%' THEN 'withdraw'
            WHEN he.topics_decoded LIKE '%deposit%'  THEN 'deposit'
        END AS event,
        CAST(json_extract(he.data_decoded,'$.map') AS array(json)) AS map_elems
    FROM stellar.history_contract_events he
    WHERE he.contract_id IN (SELECT vault FROM vault_to_token)
      AND he.topics_decoded LIKE '%DeFindexVault%'
      AND (he.topics_decoded LIKE '%withdraw%' OR he.topics_decoded LIKE '%deposit%')
),

-- get the 'to' address
addr AS (
    SELECT
        b.vault,
        b.tx_hash,
        MAX(json_extract_scalar(e,'$.val.address')) AS to_addr
    FROM base b
    CROSS JOIN UNNEST(b.map_elems) AS t(e)
    WHERE json_extract_scalar(e,'$.key.symbol') IN ('depositor','withdrawer')
    GROUP BY b.vault, b.tx_hash
),

-- get the amounts
amt AS (
    SELECT
        b.vault,
        b.tx_hash,
        SUM(
            TRY(
                CASE 
                    WHEN json_extract_scalar(a, '$.i128.hi') IS NOT NULL THEN
                        CAST(
                            CAST(json_extract_scalar(a, '$.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
                          + CAST(json_extract_scalar(a, '$.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                        AS DECIMAL(38,7))
                    WHEN json_extract_scalar(a, '$.i128') IS NOT NULL THEN
                        CAST(
                            CAST(json_extract_scalar(a, '$.i128') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                        AS DECIMAL(38,7))
                    ELSE NULL
                END
            )
        ) AS amount
    FROM base b
    CROSS JOIN UNNEST(b.map_elems) AS t(e)
    CROSS JOIN UNNEST(
        CAST(json_extract(
                e,
                CASE
                    WHEN json_extract_scalar(e,'$.key.symbol') = 'amounts'            THEN '$.val.vec'
                    WHEN json_extract_scalar(e,'$.key.symbol') = 'amounts_withdrawn'  THEN '$.val.vec'
                END
            ) AS array(json))
    ) AS t(a)
    WHERE json_extract_scalar(e,'$.key.symbol') IN ('amounts','amounts_withdrawn')
    GROUP BY b.vault, b.tx_hash
),

-- total_managed_funds_before
first_level AS (
    SELECT b.*, e
    FROM base b
    CROSS JOIN UNNEST(b.map_elems) AS t(e)
    WHERE json_extract_scalar(e,'$.key.symbol') = 'total_managed_funds_before'
),
second_level AS (
    SELECT
        f.*,
        ie
    FROM first_level f
    CROSS JOIN UNNEST(
            CAST(json_extract(f.e,'$.val.vec[0].map') AS array(json))
         ) AS t(ie)
    WHERE json_extract_scalar(ie,'$.key.symbol') = 'total_amount'
),

-- assemble final row
parsed AS (
    SELECT DISTINCT
        s.vault,
        vt.vault_name,
        vt.asset,
        vt.asset_code,
        s.closed_at,
        s.closed_at_hour,
        s.tx_hash,
        s.tx_id,
        s.event,
        a.amount,
        ad.to_addr AS "to",
        TRY(
            CASE 
                WHEN json_extract_scalar(ie, '$.val.i128.hi') IS NOT NULL THEN
                    CAST(
                        CAST(json_extract_scalar(ie, '$.val.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
                      + CAST(json_extract_scalar(ie, '$.val.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                    AS DECIMAL(38,7))
                WHEN json_extract_scalar(ie, '$.val.i128') IS NOT NULL THEN
                    CAST(
                        CAST(json_extract_scalar(ie, '$.val.i128') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                    AS DECIMAL(38,7))
                ELSE NULL
            END
        ) AS total_amount
    FROM second_level s
    LEFT JOIN addr ad ON ad.vault = s.vault AND ad.tx_hash = s.tx_hash
    LEFT JOIN amt a ON a.vault = s.vault AND a.tx_hash = s.tx_hash
    LEFT JOIN vault_to_token vt ON vt.vault = s.vault
)

SELECT
    closed_at,
    vault,
    vault_name,
    asset,
    asset_code,
    event,
    "to",
    amount,
    total_amount,
    closed_at_hour,
    tx_hash
FROM parsed
ORDER BY closed_at DESC;