-- Query: DeFindex Latest Vaults Data
-- Description: N/A
-- Source: https://dune.com/queries/5926821
-- already part of a query repo

/* ──────────────────────────────────────────────────────────────────────────
   1. Get daily filled TVL data from query 5906479
   ────────────────────────────────────────────────────────────────────────── */
WITH daily_filled AS (
    SELECT
        day,
        vault,
        vault_name,
        asset,
        asset_code,
        asset_tvl,
        usd_tvl
    FROM dune.paltalabs.query_5906479
),

/* ──────────────────────────────────────────────────────────────────────────
   2. Rank each vault by most recent day
   ────────────────────────────────────────────────────────────────────────── */
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY vault
            ORDER BY day DESC
        ) AS rn
    FROM daily_filled
)

/* ──────────────────────────────────────────────────────────────────────────
   3. Select the most recent record per vault
   ────────────────────────────────────────────────────────────────────────── */
SELECT
    day AS latest_day,
    vault,
    vault_name,
    asset,
    asset_code,
    asset_tvl,
    usd_tvl
FROM ranked
WHERE rn = 1
ORDER BY usd_tvl DESC;