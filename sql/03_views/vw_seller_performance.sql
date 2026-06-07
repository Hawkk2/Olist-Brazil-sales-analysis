-- =============================================================
-- View: vw_seller_performance
-- Purpose: Revenue, margin, delivery, and satisfaction metrics
--          per seller. Powers seller scorecard and top/bottom
--          seller tables in Tableau.
-- =============================================================

USE BrazilOlistDB;
GO

IF OBJECT_ID('dbo.vw_seller_performance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_seller_performance;
GO

CREATE VIEW dbo.vw_seller_performance AS
WITH seller_base AS (
    SELECT
        seller_id,
        seller_state,
        seller_city,

        COUNT(DISTINCT order_id)                    AS total_orders,
        SUM(order_item_id)                          AS total_units_sold,
        COUNT(DISTINCT product_category_en)         AS categories_sold,

        ROUND(SUM(price), 2)                        AS total_revenue,
        ROUND(SUM(freight_value), 2)                AS total_freight_cost,
        ROUND(SUM(contribution_margin), 2)          AS total_contribution_margin,

        CASE WHEN SUM(price) = 0 THEN 0
             ELSE ROUND(SUM(contribution_margin)
                  / SUM(price) * 100, 2)
        END                                         AS contribution_margin_pct,

        ROUND(AVG(CAST(review_score AS FLOAT)), 2)  AS avg_review_score,

        ROUND(AVG(CAST(actual_delivery_days AS FLOAT)), 1)
                                                    AS avg_delivery_days,
        ROUND(AVG(CAST(delivery_delay_days  AS FLOAT)), 1)
                                                    AS avg_delay_days,

        SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END)
                                                    AS on_time_deliveries,
        SUM(CASE WHEN delivery_status = 'Late'    THEN 1 ELSE 0 END)
                                                    AS late_deliveries,

        ROUND(
            SUM(CASE WHEN delivery_status = 'On Time' THEN 1.0 ELSE 0 END)
            / COUNT(DISTINCT order_id) * 100, 2)    AS on_time_rate_pct

    FROM dbo.vw_orders_staging
    GROUP BY seller_id, seller_state, seller_city
)
SELECT
    sb.*,

    -- Revenue rank (1 = highest revenue seller)
    RANK() OVER (ORDER BY total_revenue DESC)       AS revenue_rank,

    -- Margin rank (1 = best margin)
    RANK() OVER (ORDER BY contribution_margin_pct DESC)
                                                    AS margin_rank,

    -- Review rank (1 = highest rated)
    RANK() OVER (ORDER BY avg_review_score DESC)    AS review_rank,

    -- Delivery rank (1 = fastest)
    RANK() OVER (ORDER BY avg_delivery_days ASC)    AS delivery_rank,

    -- Overall performance tier
    CASE
        WHEN total_revenue >= 50000
         AND avg_review_score >= 4.0
         AND on_time_rate_pct >= 90  THEN 'Top Performer'
        WHEN total_revenue < 5000
          OR avg_review_score < 3.0
          OR on_time_rate_pct < 70   THEN 'Needs Improvement'
        ELSE                              'Average'
    END                                             AS performance_tier

FROM seller_base sb;
GO

PRINT 'View created: dbo.vw_seller_performance';


SELECT * FROM dbo.vw_seller_performance