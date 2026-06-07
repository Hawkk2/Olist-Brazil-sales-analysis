-- =============================================================
-- View: vw_revenue_by_state
-- Purpose: Revenue, margin, and delivery metrics by customer
--          state. Powers the Brazil choropleth map and
--          state-level bar charts in Tableau.
-- =============================================================

USE BrazilOlistDB;
GO

IF OBJECT_ID('dbo.vw_revenue_by_state', 'V') IS NOT NULL
    DROP VIEW dbo.vw_revenue_by_state;
GO

CREATE VIEW dbo.vw_revenue_by_state AS
SELECT
    customer_state,

    COUNT(DISTINCT order_id)                        AS total_orders,
    COUNT(DISTINCT customer_unique_id)              AS unique_customers,
    COUNT(DISTINCT seller_id)                       AS unique_sellers,

    -- Revenue & cost
    ROUND(SUM(price), 2)                            AS total_revenue,
    ROUND(SUM(freight_value), 2)                    AS total_freight_cost,
    ROUND(SUM(contribution_margin), 2)              AS total_contribution_margin,

    -- Margin %
    CASE WHEN SUM(price) = 0 THEN 0
         ELSE ROUND(SUM(contribution_margin)
              / SUM(price) * 100, 2)
    END                                             AS contribution_margin_pct,

    -- Avg revenue per order
    CASE WHEN COUNT(DISTINCT order_id) = 0 THEN 0
         ELSE ROUND(SUM(price)
              / COUNT(DISTINCT order_id), 2)
    END                                             AS avg_order_value,

    -- Avg freight per order (freight is higher for remote states)
    CASE WHEN COUNT(DISTINCT order_id) = 0 THEN 0
         ELSE ROUND(SUM(freight_value)
              / COUNT(DISTINCT order_id), 2)
    END                                             AS avg_freight_per_order,

    -- Delivery performance
    ROUND(AVG(CAST(actual_delivery_days   AS FLOAT)), 1)
                                                    AS avg_actual_delivery_days,
    ROUND(AVG(CAST(estimated_delivery_days AS FLOAT)), 1)
                                                    AS avg_estimated_delivery_days,
    ROUND(AVG(CAST(delivery_delay_days    AS FLOAT)), 1)
                                                    AS avg_delay_days,

    -- On-time rate
    ROUND(
        SUM(CASE WHEN delivery_status = 'On Time' THEN 1.0 ELSE 0 END)
        / COUNT(DISTINCT order_id) * 100, 2)        AS on_time_rate_pct,

    -- Customer satisfaction
    ROUND(AVG(CAST(review_score AS FLOAT)), 2)      AS avg_review_score

FROM dbo.vw_orders_staging
GROUP BY customer_state;
GO

PRINT 'View created: dbo.vw_revenue_by_state';



SELECT * FROM dbo.vw_revenue_by_state