-- =============================================================
-- View: vw_exec_summary_kpis
-- Purpose: Single-row KPI summary for Tableau executive
--          summary cards. Connect Tableau directly to this view.
-- =============================================================

USE BrazilOlistDB;
GO

IF OBJECT_ID('dbo.vw_exec_summary_kpis', 'V') IS NOT NULL
    DROP VIEW dbo.vw_exec_summary_kpis;
GO

CREATE VIEW dbo.vw_exec_summary_kpis AS
WITH base AS (
    SELECT
        COUNT(DISTINCT order_id)                    AS total_orders,
        COUNT(DISTINCT customer_unique_id)          AS unique_customers,
        COUNT(DISTINCT seller_id)                   AS total_sellers,
        COUNT(DISTINCT product_category_en)         AS total_categories,

        ROUND(SUM(price), 2)                        AS total_revenue,
        ROUND(SUM(freight_value), 2)                AS total_freight_cost,
        ROUND(SUM(contribution_margin), 2)          AS total_contribution_margin,

        ROUND(AVG(CAST(review_score AS FLOAT)), 2)  AS avg_review_score,
        ROUND(AVG(CAST(actual_delivery_days AS FLOAT)), 1)
                                                    AS avg_delivery_days,
        ROUND(AVG(CAST(delivery_delay_days  AS FLOAT)), 1)
                                                    AS avg_delay_days,

        SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END)
                                                    AS on_time_orders,
        SUM(CASE WHEN delivery_status = 'Late'    THEN 1 ELSE 0 END)
                                                    AS late_orders,

        MIN(order_date)                             AS first_order_date,
        MAX(order_date)                             AS last_order_date
    FROM dbo.vw_orders_staging
)
SELECT
    total_orders,
    unique_customers,
    total_sellers,
    total_categories,
    total_revenue,
    total_freight_cost,
    total_contribution_margin,
    avg_review_score,
    avg_delivery_days,
    avg_delay_days,
    on_time_orders,
    late_orders,
    first_order_date,
    last_order_date,

    -- Derived KPIs
    CASE WHEN total_revenue = 0 THEN 0
         ELSE ROUND(total_contribution_margin
              / total_revenue * 100, 2)
    END                                             AS overall_margin_pct,

    CASE WHEN total_orders = 0 THEN 0
         ELSE ROUND(total_revenue
              / total_orders, 2)
    END                                             AS avg_order_value,

    CASE WHEN total_orders = 0 THEN 0
         ELSE ROUND(on_time_orders * 100.0
              / total_orders, 2)
    END                                             AS on_time_rate_pct,

    CASE WHEN total_orders = 0 THEN 0
         ELSE ROUND(total_freight_cost
              / total_revenue * 100, 2)
    END                                             AS freight_as_pct_of_revenue

FROM base;
GO

PRINT 'View created: dbo.vw_exec_summary_kpis';
