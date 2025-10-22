-- Query: DeFindex Vaults with more info (Name, Assets, Symbol)
-- Description: Currently only supporting Vaults with one asset!
It does take only the first asset of the list!!!!
-- Source: https://dune.com/queries/5782251
-- already part of a query repo

WITH vaults AS (
    SELECT
        v.vault,
        cd.val_decoded,
        ROW_NUMBER() OVER (
            PARTITION BY v.vault
            ORDER BY cd.closed_at DESC
        ) AS rn
    FROM query_5268612 v
    JOIN stellar.contract_data cd
      ON cd.contract_id = v.vault
    WHERE cd.contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
),
latest AS (
    SELECT
        vault,
        json_parse(val_decoded) AS instance_json
    FROM vaults
    WHERE rn = 1
),
parsed AS (
    SELECT
        vault,
        -- METADATA: name
        json_extract_scalar(instance_json, '$.contract_instance.storage[0].val.map[1].val.string') AS name,
        -- METADATA: symbol
        json_extract_scalar(instance_json, '$.contract_instance.storage[0].val.map[2].val.string') AS symbol,
        -- First AssetStrategySet → asset address
        json_extract_scalar(instance_json, '$.contract_instance.storage[1].val.map[0].val.address') AS asset
    FROM latest
),
asset_contracts AS (
    SELECT
        JSON_EXTRACT_SCALAR(val_decoded, '$.value') AS decoded_data,
        contract_id,
        CASE
            WHEN asset_code = ''
                 AND contract_id = 'CAS3J7GYLGXMF6TDJBBYYSE3HQ6BBSMLNUQ34T6TZMYMW2EVH34XOWMA'
                 THEN 'XLM'
            ELSE asset_code
        END AS asset_code
    FROM stellar.contract_data cd
    WHERE contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
      AND ledger_sequence = (
          SELECT MAX(cd2.ledger_sequence)
          FROM stellar.contract_data cd2
          WHERE cd2.contract_id       = cd.contract_id
            AND cd2.contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
      )
)
SELECT
    p.vault,
    -- Clean vault name and add suffix
    REGEXP_REPLACE(p.name, '^DeFindex-Vault-', '') 
        || ' - ' 
        || SUBSTRING(p.vault, 1, 3) 
        || '..' 
        || SUBSTRING(p.vault, LENGTH(p.vault) - 2, 3)
        AS vault_name,
    p.symbol AS vault_symbol,
    p.asset,
    COALESCE(NULLIF(a.asset_code, ''), 'UNKNOWN') AS asset_code
FROM parsed p
LEFT JOIN asset_contracts a
  ON p.asset = a.contract_id
ORDER BY p.vault;