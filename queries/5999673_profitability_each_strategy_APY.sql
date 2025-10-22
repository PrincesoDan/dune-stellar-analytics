-- Query: Strategy APY Calculation
-- Description: Calculates APY for each strategy based on price_per_share changes
-- Shows APY for 24h, 7d, and 30d periods using harvest events
-- APY Formula: ((last_pps / first_pps) ^ (365.2425 * MS_PER_DAY / timeDifference) - 1) * 100

WITH strategy_list AS (
    -- Get YieldBlox strategy contracts from summary_strategies table (query_6014850)
    SELECT
        strategy_address AS contract_id,
        asset_token AS asset,
        strategy_name
    FROM query_6014850
    WHERE strategy_name LIKE '%yieldblox_strategy%'
      AND asset_token IN ('USDC', 'EURC', 'XLM')
),

harvest_data AS (
    -- Reference the harvest events query (5974662)
    SELECT
        closed_at,
        asset,
        contract_id,
        price_per_share
    FROM query_5974662
    WHERE price_per_share IS NOT NULL
        AND price_per_share > 0
),

-- Calculate current time reference
latest_time AS (
    SELECT MAX(closed_at) AS max_time
    FROM harvest_data
),

-- Get first and last PPS for each period and strategy
period_ranges AS (
    SELECT
        sl.contract_id,
        sl.asset,
        -- 24h period
        MIN(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '24' HOUR THEN h.closed_at END) AS first_time_24h,
        MAX(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '24' HOUR THEN h.closed_at END) AS last_time_24h,
        COUNT(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '24' HOUR THEN 1 END) AS count_24h,
        -- 7d period
        MIN(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '7' DAY THEN h.closed_at END) AS first_time_7d,
        MAX(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '7' DAY THEN h.closed_at END) AS last_time_7d,
        COUNT(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '7' DAY THEN 1 END) AS count_7d,
        -- 30d period
        MIN(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '30' DAY THEN h.closed_at END) AS first_time_30d,
        MAX(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '30' DAY THEN h.closed_at END) AS last_time_30d,
        COUNT(CASE WHEN h.closed_at >= lt.max_time - INTERVAL '30' DAY THEN 1 END) AS count_30d
    FROM strategy_list sl
    CROSS JOIN latest_time lt
    LEFT JOIN harvest_data h ON h.contract_id = sl.contract_id
    GROUP BY sl.contract_id, sl.asset
),

-- Get PPS values at the calculated time points
pps_values AS (
    SELECT
        pr.contract_id,
        pr.asset,
        -- 24h values
        MAX(CASE WHEN h.closed_at = pr.first_time_24h THEN h.price_per_share END) AS pps_24h_start,
        MAX(CASE WHEN h.closed_at = pr.last_time_24h THEN h.price_per_share END) AS pps_24h_end,
        pr.first_time_24h,
        pr.last_time_24h,
        pr.count_24h,
        -- 7d values
        MAX(CASE WHEN h.closed_at = pr.first_time_7d THEN h.price_per_share END) AS pps_7d_start,
        MAX(CASE WHEN h.closed_at = pr.last_time_7d THEN h.price_per_share END) AS pps_7d_end,
        pr.first_time_7d,
        pr.last_time_7d,
        pr.count_7d,
        -- 30d values
        MAX(CASE WHEN h.closed_at = pr.first_time_30d THEN h.price_per_share END) AS pps_30d_start,
        MAX(CASE WHEN h.closed_at = pr.last_time_30d THEN h.price_per_share END) AS pps_30d_end,
        pr.first_time_30d,
        pr.last_time_30d,
        pr.count_30d
    FROM period_ranges pr
    LEFT JOIN harvest_data h
        ON h.contract_id = pr.contract_id
        AND (
            h.closed_at = pr.first_time_24h OR h.closed_at = pr.last_time_24h OR
            h.closed_at = pr.first_time_7d OR h.closed_at = pr.last_time_7d OR
            h.closed_at = pr.first_time_30d OR h.closed_at = pr.last_time_30d
        )
    GROUP BY pr.contract_id, pr.asset,
             pr.first_time_24h, pr.last_time_24h, pr.count_24h,
             pr.first_time_7d, pr.last_time_7d, pr.count_7d,
             pr.first_time_30d, pr.last_time_30d, pr.count_30d
)

-- Calculate APY for each period
SELECT
    asset,
    contract_id,

    -- 24h APY
    CASE
        WHEN pps_24h_start IS NOT NULL
            AND pps_24h_end IS NOT NULL
            AND pps_24h_start > 0
            AND last_time_24h > first_time_24h
        THEN ROUND(
            CAST(
                (POWER(
                    pps_24h_end / pps_24h_start,
                    365.2425 * 86400000.0 / (TO_UNIXTIME(last_time_24h) * 1000.0 - TO_UNIXTIME(first_time_24h) * 1000.0)
                ) - 1) * 100
            AS DECIMAL(38,2))
        , 2)
        ELSE NULL
    END AS apy_24h,

    -- 7d APY
    CASE
        WHEN pps_7d_start IS NOT NULL
            AND pps_7d_end IS NOT NULL
            AND pps_7d_start > 0
            AND last_time_7d > first_time_7d
        THEN ROUND(
            CAST(
                (POWER(
                    pps_7d_end / pps_7d_start,
                    365.2425 * 86400000.0 / (TO_UNIXTIME(last_time_7d) * 1000.0 - TO_UNIXTIME(first_time_7d) * 1000.0)
                ) - 1) * 100
            AS DECIMAL(38,2))
        , 2)
        ELSE NULL
    END AS apy_7d,

    -- 30d APY
    CASE
        WHEN pps_30d_start IS NOT NULL
            AND pps_30d_end IS NOT NULL
            AND pps_30d_start > 0
            AND last_time_30d > first_time_30d
        THEN ROUND(
            CAST(
                (POWER(
                    pps_30d_end / pps_30d_start,
                    365.2425 * 86400000.0 / (TO_UNIXTIME(last_time_30d) * 1000.0 - TO_UNIXTIME(first_time_30d) * 1000.0)
                ) - 1) * 100
            AS DECIMAL(38,2))
        , 2)
        ELSE NULL
    END AS apy_30d,

    -- Additional context columns
    -- Event counts for diagnostics
    count_24h AS events_24h,
    count_7d AS events_7d,
    count_30d AS events_30d,

    -- PPS values for reference
    pps_24h_start,
    pps_24h_end,
    first_time_24h,
    last_time_24h,
    pps_7d_start,
    pps_7d_end,
    first_time_7d,
    last_time_7d,
    pps_30d_start,
    pps_30d_end,
    first_time_30d,
    last_time_30d

FROM pps_values
ORDER BY asset, contract_id;
