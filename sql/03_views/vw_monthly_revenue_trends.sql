-- =============================================================
-- View: vw_monthly_revenue_trends
-- Purpose: Month-over-month revenue and margin trends with
--          period-over-period comparisons. Powers the dual-axis
--          trend line chart and YoY growth cards in Tableau.
-- =============================================================

USE BrazilOlistDB;
GO

IF OBJECT_ID('dbo.vw_monthly_revenue_trends', 'V') IS NOT NULL
    DROP VIEW dbo.vw_monthly_revenue_trends;
GO

CREATE VIEW dbo.vw_monthly_revenue_trends AS
WITH monthly_base AS (
    SELECT
        order_year,
        order_month,
        order_month_start,

        COUNT(DISTINCT order_id)                    AS total_orders,
        COUNT(DISTINCT customer_unique_id)          AS unique_customers,

        ROUND(SUM(price), 2)                        AS total_revenue,
        ROUND(SUM(freight_value), 2)                AS total_freight_cost,
        ROUND(SUM(contribution_margin), 2)          AS total_contribution_margin,

        CASE WHEN SUM(price) = 0 THEN 0
             ELSE ROUND(SUM(contribution_margin)
                  / SUM(price) * 100, 2)
        END                                         AS contribution_margin_pct,

        ROUND(AVG(CAST(review_score AS FLOAT)), 2)  AS avg_review_score,
        ROUND(AVG(CAST(actual_delivery_days AS FLOAT)), 1)
                                                    AS avg_delivery_days

    FROM dbo.vw_orders_staging
    GROUP BY order_year, order_month, order_month_start
)
SELECT
    mb.*,

    -- Prior month values for MoM comparison
    LAG(total_revenue) OVER (
        ORDER BY order_month_start)                 AS prev_month_revenue,

    LAG(total_orders) OVER (
        ORDER BY order_month_start)                 AS prev_month_orders,

    -- MoM revenue growth %
    CASE
        WHEN LAG(total_revenue) OVER (ORDER BY order_month_start) IS NULL
          OR LAG(total_revenue) OVER (ORDER BY order_month_start) = 0
        THEN NULL
        ELSE ROUND(
            (total_revenue
             - LAG(total_revenue) OVER (ORDER BY order_month_start))
            / LAG(total_revenue) OVER (ORDER BY order_month_start)
            * 100, 2)
    END                                             AS mom_revenue_growth_pct,

    -- Same month prior year
    LAG(total_revenue, 12) OVER (
        ORDER BY order_month_start)                 AS same_month_prior_year_revenue,

    -- YoY growth %
    CASE
        WHEN LAG(total_revenue, 12) OVER (ORDER BY order_month_start) IS NULL
          OR LAG(total_revenue, 12) OVER (ORDER BY order_month_start) = 0
        THEN NULL
        ELSE ROUND(
            (total_revenue
             - LAG(total_revenue, 12) OVER (ORDER BY order_month_start))
            / LAG(total_revenue, 12) OVER (ORDER BY order_month_start)
            * 100, 2)
    END                                             AS yoy_revenue_growth_pct,

    -- Running total revenue
    SUM(total_revenue) OVER (
        ORDER BY order_month_start
        ROWS UNBOUNDED PRECEDING)                   AS running_total_revenue,

    -- Running total orders
    SUM(total_orders) OVER (
        ORDER BY order_month_start
        ROWS UNBOUNDED PRECEDING)                   AS running_total_orders

FROM monthly_base mb;
GO

PRINT 'View created: dbo.vw_monthly_revenue_trends';
