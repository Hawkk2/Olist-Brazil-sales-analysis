-- =============================================================
-- View: vw_delivery_performance
-- Purpose: Actual vs. estimated delivery analysis by category
--          and customer state. Powers on-time rate KPIs,
--          delay distribution charts, and the delivery
--          heatmap in Tableau.
-- =============================================================

USE BrazilOlistDB;
GO


IF OBJECT_ID('dbo.vw_delivery_performance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_delivery_performance;
GO

CREATE VIEW dbo.vw_delivery_performance AS
SELECT
    customer_state,
    product_category_en,
    order_year,
    order_month,
    order_month_start,

    COUNT(DISTINCT order_id)                        AS total_orders,

    -- Delivery status breakdown
    SUM(CASE WHEN delivery_status = 'On Time'       THEN 1 ELSE 0 END)
                                                    AS on_time_count,
    SUM(CASE WHEN delivery_status = 'Late'          THEN 1 ELSE 0 END)
                                                    AS late_count,
    SUM(CASE WHEN delivery_status = 'Not Delivered' THEN 1 ELSE 0 END)
                                                    AS not_delivered_count,

    -- On-time rate %
    ROUND(
        SUM(CASE WHEN delivery_status = 'On Time' THEN 1.0 ELSE 0 END)
        / COUNT(DISTINCT order_id) * 100, 2)        AS on_time_rate_pct,

    -- Late rate %
    ROUND(
        SUM(CASE WHEN delivery_status = 'Late' THEN 1.0 ELSE 0 END)
        / COUNT(DISTINCT order_id) * 100, 2)        AS late_rate_pct,

    -- Delivery speed
    ROUND(AVG(CAST(estimated_delivery_days AS FLOAT)), 1)
                                                    AS avg_estimated_days,
    ROUND(AVG(CAST(actual_delivery_days    AS FLOAT)), 1)
                                                    AS avg_actual_days,
    ROUND(AVG(CAST(delivery_delay_days     AS FLOAT)), 1)
                                                    AS avg_delay_days,

    -- Delay distribution
    MAX(delivery_delay_days)                        AS max_delay_days,
    MIN(delivery_delay_days)                        AS min_delay_days,

    -- Orders delivered early (negative delay = arrived before estimate)
    SUM(CASE WHEN delivery_delay_days < 0 THEN 1 ELSE 0 END)
                                                    AS early_count,
    ROUND(AVG(CASE WHEN delivery_delay_days < 0
                   THEN CAST(delivery_delay_days AS FLOAT)
              END), 1)                              AS avg_days_early,

    -- Orders late by severity
    SUM(CASE WHEN delivery_delay_days BETWEEN 1 AND 7  THEN 1 ELSE 0 END)
                                                    AS late_1_7_days,
    SUM(CASE WHEN delivery_delay_days BETWEEN 8 AND 14 THEN 1 ELSE 0 END)
                                                    AS late_8_14_days,
    SUM(CASE WHEN delivery_delay_days > 14            THEN 1 ELSE 0 END)
                                                    AS late_over_14_days,

    -- Review score correlation with delivery
    ROUND(AVG(CAST(review_score AS FLOAT)), 2)      AS avg_review_score,
    ROUND(AVG(CASE WHEN delivery_status = 'On Time'
                   THEN CAST(review_score AS FLOAT) END), 2)
                                                    AS avg_review_on_time,
    ROUND(AVG(CASE WHEN delivery_status = 'Late'
                   THEN CAST(review_score AS FLOAT) END), 2)
                                                    AS avg_review_late

FROM dbo.vw_orders_staging
WHERE actual_delivery_days IS NOT NULL
GROUP BY
    customer_state,
    product_category_en,
    order_year,
    order_month,
    order_month_start;
GO

PRINT 'View created: dbo.vw_delivery_performance';


SELECT * FROM dbo.vw_delivery_performance