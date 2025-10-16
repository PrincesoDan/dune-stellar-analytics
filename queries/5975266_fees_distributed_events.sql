-- Query: DeFindex Vaults - FeesDistributed Events
-- Description: Shows all FeesDistributed events from DeFindex vaults with distributed fees details
-- Event structure: distributed_fees: Vec<(Address, i128)>
-- Source: Based on defindex_vaults_events query structure

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
        he.topics_decoded,
        CAST(json_extract(he.data_decoded,'$.map') AS array(json)) AS map_elems
    FROM stellar.history_contract_events he
    WHERE he.contract_id IN (SELECT vault FROM vault_to_token)
      AND he.topics_decoded LIKE '%DeFindexVault%'
      AND he.topics_decoded LIKE '%dfees%'
),

-- Extract the distributed_fees vector
distributed_fees_vec AS (
    SELECT
        b.vault,
        b.closed_at,
        b.closed_at_hour,
        b.tx_hash,
        b.tx_id,
        -- Extract the vec from distributed_fees field
        CAST(json_extract(e, '$.val.vec') AS array(json)) AS fees_vec
    FROM base b
    CROSS JOIN UNNEST(b.map_elems) AS t(e)
    WHERE json_extract_scalar(e,'$.key.symbol') = 'distributed_fees'
),

-- Expand each tuple (Address, i128) in the vector
expanded_fees AS (
    SELECT
        df.vault,
        df.closed_at,
        df.closed_at_hour,
        df.tx_hash,
        df.tx_id,
        fee_tuple
    FROM distributed_fees_vec df
    CROSS JOIN UNNEST(df.fees_vec) AS t(fee_tuple)
),

-- Parse each tuple to extract address and amount
parsed_fees AS (
    SELECT
        ef.vault,
        ef.closed_at,
        ef.closed_at_hour,
        ef.tx_hash,
        ef.tx_id,
        -- Extract address from first element of tuple (vec[0])
        json_extract_scalar(
            CAST(json_extract(ef.fee_tuple, '$.vec[0]') AS json),
            '$.address'
        ) AS recipient_address,
        -- Extract i128 amount from second element of tuple (vec[1])
        TRY(
            CASE
                WHEN json_extract_scalar(
                    CAST(json_extract(ef.fee_tuple, '$.vec[1]') AS json),
                    '$.i128.hi'
                ) IS NOT NULL THEN
                    CAST(
                        CAST(json_extract_scalar(
                            CAST(json_extract(ef.fee_tuple, '$.vec[1]') AS json),
                            '$.i128.hi'
                        ) AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
                      + CAST(json_extract_scalar(
                            CAST(json_extract(ef.fee_tuple, '$.vec[1]') AS json),
                            '$.i128.lo'
                        ) AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                    AS DECIMAL(38,7))
                WHEN json_extract_scalar(
                    CAST(json_extract(ef.fee_tuple, '$.vec[1]') AS json),
                    '$.i128'
                ) IS NOT NULL THEN
                    CAST(
                        CAST(json_extract_scalar(
                            CAST(json_extract(ef.fee_tuple, '$.vec[1]') AS json),
                            '$.i128'
                        ) AS DECIMAL(38,0)) * DECIMAL '0.0000001'
                    AS DECIMAL(38,7))
                ELSE NULL
            END
        ) AS fee_amount
    FROM expanded_fees ef
)

-- Final assembly
SELECT
    pf.closed_at,
    pf.closed_at_hour,
    pf.vault,
    vt.vault_name,
    vt.asset,
    vt.asset_code,
    pf.recipient_address,
    pf.fee_amount,
    pf.tx_hash,
    pf.tx_id
FROM parsed_fees pf
LEFT JOIN vault_to_token vt ON vt.vault = pf.vault
ORDER BY pf.closed_at DESC, pf.vault, pf.recipient_address;
