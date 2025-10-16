-- Query: Explore Report Data Structure
-- Description: Simple query to inspect the raw structure of Report keys in contract_data
-- Use this to verify the data structure before running the full locked_fees query


WITH vault_list AS (
    SELECT vault
    FROM query_5782251
    LIMIT 5  -- Only check first 5 vaults for exploration
)

SELECT
    cd.contract_id AS vault,
    cd.closed_at,
    cd.ledger_sequence,
    cd.contract_key_type,
    cd.key_decoded,
    cd.val_decoded,
    cd.last_modified_ledger
FROM stellar.contract_data cd
WHERE cd.contract_id IN (SELECT vault FROM vault_list)
  AND cd.key_decoded LIKE '%Report%'
  AND cd.deleted = false
ORDER BY cd.closed_at DESC
LIMIT 10;

