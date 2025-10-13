-- Query: DeFindex Vaults
-- Description: N/A
-- Source: https://dune.com/queries/5268612
-- already part of a query repo

WITH vaults AS (
    SELECT
        cd.closed_at,
        CAST(JSON_PARSE(cd.val_decoded) AS JSON) AS vault_json
    FROM stellar.contract_data cd
    WHERE cd.contract_id = 'CDKFHFJIET3A73A2YN4KV7NSV32S6YGQMUFH3DNJXLBWL4SKEGVRNFKI'
      AND cd.contract_key_type = 'ScValTypeScvVec'
)
SELECT
    closed_at,
    json_extract_scalar(vault_json, '$.address') AS vault
FROM vaults
ORDER BY closed_at;
