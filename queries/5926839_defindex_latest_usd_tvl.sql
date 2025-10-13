-- Query: DeFindex Latest USD TVL
-- Description: N/A
-- Source: https://dune.com/queries/5926839
-- already part of a query repo

/* ──────────────────────────────────────────────────────────────────────────
   1. Get latest per-vault data from query 5926821
   ────────────────────────────────────────────────────────────────────────── */
WITH latest_vaults AS (
    SELECT
        vault,
        vault_name,
        asset,
        asset_code,
        asset_tvl,
        usd_tvl
    FROM dune.paltalabs.query_5926821
)

/* ──────────────────────────────────────────────────────────────────────────
   2. Sum total USD TVL across all vaults
   ────────────────────────────────────────────────────────────────────────── */
SELECT
    SUM(usd_tvl) AS total_usd_tvl
FROM latest_vaults;
