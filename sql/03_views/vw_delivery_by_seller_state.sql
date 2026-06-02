-- =============================================================
-- View: vw_delivery_by_seller_state
-- Purpose: Delivery performance grouped by seller state.
--          Identifies which seller regions are driving late
--          deliveries. Powers the seller delivery scorecard
--          and state comparison map in Tableau.
-- =============================================================

USE BrazilOlistDB;
GO

IF OBJECT_ID('dbo.vw_delivery_by_seller_state', 'V') IS NOT NULL
    DROP VIEW dbo.vw_delivery_by_seller_state;
GO

CREATE VIEW dbo.vw_delivery_by_seller_state AS
WITH seller_delivery AS (
    SELECT
        seller_state,
        seller_id,

        COUNT(DISTINCT order_id)                    AS total_orders,

        SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END)
                                                    AS on_time_count,
        SUM(CASE WHEN delivery_status = 'Late'    THEN 1 ELSE 0 END)
                                                    AS late_count,

        ROUND(AVG(CAST(actual_delivery_days   AS FLOAT)), 1)
                                                    AS avg_actual_days,
        ROUND(AVG(CAST(delivery_delay_days    AS FLOAT)), 1)
                                                    AS avg_delay_days,
        ROUND(AVG(CAST(review_score           AS FLOAT)), 2)
                                                    AS avg_review_score,
        ROUND(SUM(price), 2)                        AS total_revenue

    FROM dbo.vw_orders_staging
    WHERE actual_delivery_days IS NOT NULL
    GROUP BY seller_state, seller_id
)
SELECT
    seller_state,

    COUNT(DISTINCT seller_id)                       AS total_sellers,
    SUM(total_orders)                               AS total_orders,
    SUM(on_time_count)                              AS on_time_count,
    SUM(late_count)                                 AS late_count,

    ROUND(SUM(on_time_count) * 100.0
          / NULLIF(SUM(total_orders), 0), 2)        AS on_time_rate_pct,

    ROUND(AVG(avg_actual_days), 1)                  AS avg_actual_delivery_days,
    ROUND(AVG(avg_delay_days),  1)                  AS avg_delay_days,
    ROUND(AVG(avg_review_score), 2)                 AS avg_review_score,
    ROUND(SUM(total_revenue), 2)                    AS total_revenue,

    -- State delivery tier for Tableau color encoding
    CASE
        WHEN ROUND(SUM(on_time_count) * 100.0
             / NULLIF(SUM(total_orders), 0), 2) >= 90  THEN 'Strong'
        WHEN ROUND(SUM(on_time_count) * 100.0
             / NULLIF(SUM(total_orders), 0), 2) >= 75  THEN 'Average'
        ELSE                                                 'Poor'
    END                                             AS delivery_tier

FROM seller_delivery
GROUP BY seller_state;
GO

PRINT 'View created: dbo.vw_delivery_by_seller_state';
