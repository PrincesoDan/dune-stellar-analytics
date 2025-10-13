-- Query: DeFindex Vaults TVL, filled days
-- Description: Max TVL per vault per day. Filtered by Vaults with at least one day with positive TVL
-- Source: https://dune.com/queries/5906479
-- already part of a query repo

/* ──────────────────────────────────────────────────────────────────────────
   1. Get existing TVL data from query 5901637
   ────────────────────────────────────────────────────────────────────────── */
WITH base_tvl AS (
    SELECT
        hour,
        vault,
        vault_name,
        asset,
        asset_code,
        asset_tvl,
        asset_price,
        usd_tvl
    FROM dune.paltalabs.query_5901637
),

/* ──────────────────────────────────────────────────────────────────────────
   2. Aggregate to get the maximum asset_tvl per vault per day
   ────────────────────────────────────────────────────────────────────────── */
daily_max_tvl AS (
    SELECT
        DATE_TRUNC('day', hour) AS day,
        vault,
        vault_name,
        asset,
        asset_code,
        MAX(asset_tvl) AS asset_tvl,
        MAX(usd_tvl) AS usd_tvl
    FROM base_tvl
    GROUP BY
        DATE_TRUNC('day', hour),
        vault,
        vault_name,
        asset,
        asset_code
),

/* ──────────────────────────────────────────────────────────────────────────
   3. Identify vaults with non-zero asset_tvl at least once
   ────────────────────────────────────────────────────────────────────────── */
non_zero_vaults AS (
    SELECT DISTINCT
        vault,
        vault_name,
        asset,
        asset_code
    FROM daily_max_tvl
    WHERE asset_tvl > 0
),

/* ──────────────────────────────────────────────────────────────────────────
   4. Get time range for days
   ────────────────────────────────────────────────────────────────────────── */
time_range AS (
    SELECT
        CAST(MIN(day) AS TIMESTAMP) AS min_day,
        CAST(MAX(day) AS TIMESTAMP) AS max_day
    FROM daily_max_tvl
),

/* ──────────────────────────────────────────────────────────────────────────
   5. Generate all days for the time range
   ────────────────────────────────────────────────────────────────────────── */
all_days AS (
    SELECT
        day_seq AS day
    FROM time_range
    CROSS JOIN UNNEST(
        SEQUENCE(
            time_range.min_day,
            time_range.max_day,
            INTERVAL '1' DAY
        )
    ) AS t(day_seq)
),

/* ──────────────────────────────────────────────────────────────────────────
   6. Create complete day x vault grid for non-zero vaults
   ────────────────────────────────────────────────────────────────────────── */
complete_grid AS (
    SELECT
        d.day,
        v.vault,
        v.vault_name,
        v.asset,
        v.asset_code
    FROM all_days d
    CROSS JOIN non_zero_vaults v
),

/* ──────────────────────────────────────────────────────────────────────────
   7. Join grid with daily max TVL data
   ────────────────────────────────────────────────────────────────────────── */
grid_with_tvl AS (
    SELECT
        g.day,
        g.vault,
        g.vault_name,
        g.asset,
        g.asset_code,
        t.asset_tvl,
        t.usd_tvl
    FROM complete_grid g
    LEFT JOIN daily_max_tvl t
        ON g.day = t.day
        AND g.vault = t.vault
),

/* ──────────────────────────────────────────────────────────────────────────
   8. Create groups for forward fill (partition by vault and presence of data)
   ────────────────────────────────────────────────────────────────────────── */
with_groups AS (
    SELECT
        day,
        vault,
        vault_name,
        asset,
        asset_code,
        asset_tvl,
        usd_tvl,
        SUM(CASE WHEN asset_tvl IS NOT NULL THEN 1 ELSE 0 END) OVER (
            PARTITION BY vault
            ORDER BY day
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS tvl_group
    FROM grid_with_tvl
),

/* ──────────────────────────────────────────────────────────────────────────
   9. Fill forward using FIRST_VALUE within each group
   ────────────────────────────────────────────────────────────────────────── */
filled_tvl AS (
    SELECT
        day,
        vault,
        vault_name,
        asset,
        asset_code,
        CAST(
            FIRST_VALUE(asset_tvl) OVER (
                PARTITION BY vault, tvl_group
                ORDER BY day
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS DECIMAL(38,7)
        ) AS asset_tvl,
        CAST(
            FIRST_VALUE(usd_tvl) OVER (
                PARTITION BY vault, tvl_group
                ORDER BY day
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS DECIMAL(38,7)
        ) AS usd_tvl
    FROM with_groups
)

/* ──────────────────────────────────────────────────────────────────────────
   10. Final output with all days filled
   ────────────────────────────────────────────────────────────────────────── */
SELECT
    day,
    vault,
    vault_name,
    asset,
    asset_code,
    asset_tvl,
    usd_tvl
FROM filled_tvl
WHERE asset_tvl IS NOT NULL
ORDER BY day DESC, vault;
