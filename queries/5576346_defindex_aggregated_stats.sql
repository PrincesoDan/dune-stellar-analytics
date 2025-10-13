-- Query: DeFindex Aggregated Stats
-- Description: N/A
-- Source: https://dune.com/queries/5576346
-- already part of a query repo

WITH events AS (
    SELECT
        vault,
        vault_name,
        "to"        AS account,
        event,      -- 'deposit' | 'withdraw'
        tx_hash
    FROM dune.paltalabs.result_de_findex_vaults_events
),

-- Totals per vault
per_vault AS (
    SELECT
        vault,
        vault_name,
        COUNT(DISTINCT account) AS total_accounts,
        COUNT(DISTINCT tx_hash) AS total_txs
    FROM events
    GROUP BY vault, vault_name
),

-- Overall totals across all vaults
overall AS (
    SELECT
        COUNT(DISTINCT account) AS total_accounts,
        COUNT(DISTINCT tx_hash) AS total_txs
    FROM events
)

SELECT 
    pv.vault,
    pv.vault_name,
    pv.total_accounts,
    pv.total_txs,
    o.total_accounts   AS total_accounts_all,
    o.total_txs       AS total_txs_all
FROM per_vault pv
CROSS JOIN overall o
ORDER BY pv.total_accounts DESC;