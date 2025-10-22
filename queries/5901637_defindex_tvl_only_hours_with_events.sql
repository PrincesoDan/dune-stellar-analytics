-- Query: DeFindex TVL only hours with events
-- Description: N/A
-- Source: https://dune.com/queries/5901637
-- already part of a query repo

/* ──────────────────────────────────────────────────────────────────────────
   1. Vault-contract to token-contract mapping (all vaults)
   ────────────────────────────────────────────────────────────────────────── */
WITH vault_to_token AS (
    SELECT
        vault,
        vault_name,
        asset,
        asset_code
    FROM dune.paltalabs.result_de_findex_vaults_with_more_info_name_assets_symbol
),

/* ──────────────────────────────────────────────────────────────────────────
   2. Hourly-bucketed vault events (aggregate if >1 per vault+hour)
   ────────────────────────────────────────────────────────────────────────── */
events AS (
    SELECT
        m.vault,
        m.vault_name,
        m.asset,
        m.asset_code,
        DATE_TRUNC('hour', ve.closed_at) AS hour,
        MAX(ve.total_amount) AS total_amount
    FROM dune.paltalabs.result_de_findex_vaults_events ve
    JOIN vault_to_token m ON ve.vault = m.vault
    GROUP BY
        m.vault, m.vault_name, m.asset, m.asset_code,
        DATE_TRUNC('hour', ve.closed_at)
),

/* ──────────────────────────────────────────────────────────────────────────
   3. Deduplicated daily prices since March 1, 2024
   ────────────────────────────────────────────────────────────────────────── */
prices AS (
    SELECT
        contract_id AS token,
        price,
        closed_at_day AS hour
    FROM (
        SELECT
            contract_id,
            closed_at_day,
            price,
            ROW_NUMBER() OVER (
                PARTITION BY contract_id, closed_at_day
                ORDER BY closed_at_day DESC
            ) AS rn
        FROM dune.paltalabs."result_soroswap_tokens_sdex_prices_daily_since_march_2024"
    ) t
    WHERE rn = 1
),

/* ──────────────────────────────────────────────────────────────────────────
   4. Join events to same-day price (USDC price = 1)
   ────────────────────────────────────────────────────────────────────────── */
tvl_vault_hour AS (
    SELECT
        e.hour,
        e.vault,
        e.vault_name,
        e.asset,
        e.asset_code,
        e.total_amount AS asset_tvl,
        CASE
            WHEN e.asset_code = 'USDC' THEN CAST(1 AS DECIMAL(38,7))
            ELSE p.price
        END AS asset_price
    FROM events e
    LEFT JOIN prices p
        ON p.token = e.asset
        AND DATE_TRUNC('day', e.hour) = p.hour
    WHERE (e.asset_code = 'USDC')
       OR (p.price IS NOT NULL)
)

/* ──────────────────────────────────────────────────────────────────────────
   5. Final TVL per vault/hour
   ────────────────────────────────────────────────────────────────────────── */
SELECT
    hour,
    vault,
    vault_name,
    asset,
    asset_code,
    asset_tvl,
    asset_price,
    CAST(asset_tvl * asset_price AS DECIMAL(38,7)) AS usd_tvl
FROM tvl_vault_hour
ORDER BY hour DESC, vault;