-- =============================================================
-- View: vw_revenue_by_category
-- Purpose: Revenue, freight cost, and contribution margin by
--          English product category. Powers the category
--          treemap and ranked bar charts in Tableau.
-- =============================================================

USE BrazilOlistDB;
GO

IF OBJECT_ID('dbo.vw_revenue_by_category', 'V') IS NOT NULL
    DROP VIEW dbo.vw_revenue_by_category;
GO

CREATE VIEW dbo.vw_revenue_by_category AS
SELECT
    product_category_en,

    COUNT(DISTINCT order_id)                        AS total_orders,
    COUNT(DISTINCT product_id)                      AS unique_products,
    COUNT(DISTINCT seller_id)                       AS unique_sellers,
    SUM(order_item_id)                              AS total_units_sold,

    -- Revenue & cost
    ROUND(SUM(price), 2)                            AS total_revenue,
    ROUND(SUM(freight_value), 2)                    AS total_freight_cost,
    ROUND(SUM(contribution_margin), 2)              AS total_contribution_margin,

    -- Margin %
    CASE WHEN SUM(price) = 0 THEN 0
         ELSE ROUND(SUM(contribution_margin)
              / SUM(price) * 100, 2)
    END                                             AS contribution_margin_pct,

    -- Avg order value
    CASE WHEN COUNT(DISTINCT order_id) = 0 THEN 0
         ELSE ROUND(SUM(price)
              / COUNT(DISTINCT order_id), 2)
    END                                             AS avg_order_value,

    -- Avg freight per item
    CASE WHEN SUM(order_item_id) = 0 THEN 0
         ELSE ROUND(SUM(freight_value)
              / SUM(order_item_id), 2)
    END                                             AS avg_freight_per_item,

    -- Customer satisfaction
    ROUND(AVG(CAST(review_score AS FLOAT)), 2)      AS avg_review_score,

    -- Delivery
    ROUND(AVG(CAST(actual_delivery_days AS FLOAT)), 1)
                                                    AS avg_delivery_days,

    -- Profit health flag for Tableau color encoding
    CASE
        WHEN SUM(contribution_margin) < 0              THEN 'Negative Margin'
        WHEN SUM(contribution_margin)
           / NULLIF(SUM(price), 0) * 100 < 10          THEN 'Low Margin'
        ELSE                                                 'Healthy'
    END                                             AS margin_health

FROM dbo.vw_orders_staging
GROUP BY product_category_en;
GO

PRINT 'View created: dbo.vw_revenue_by_category';
