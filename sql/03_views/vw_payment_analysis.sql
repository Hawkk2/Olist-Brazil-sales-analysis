-- =============================================================
-- View: vw_payment_analysis
-- Purpose: Payment method distribution, installment usage,
--          and revenue by payment type. Powers payment
--          breakdown charts in Tableau.
-- =============================================================

USE BrazilOlistDB;
GO

IF OBJECT_ID('dbo.vw_payment_analysis', 'V') IS NOT NULL
    DROP VIEW dbo.vw_payment_analysis;
GO

CREATE VIEW dbo.vw_payment_analysis AS
WITH base AS (
    SELECT
        payment_type,

        COUNT(DISTINCT order_id)                    AS total_orders,

        ROUND(SUM(payment_value), 2)                AS total_payment_value,
        ROUND(AVG(payment_value), 2)                AS avg_payment_value,
        ROUND(AVG(CAST(payment_installments AS FLOAT)), 1)
                                                    AS avg_installments,

        -- Installment buckets
        SUM(CASE WHEN payment_installments = 1  THEN 1 ELSE 0 END)
                                                    AS single_payment_orders,
        SUM(CASE WHEN payment_installments BETWEEN 2 AND 6
                                                THEN 1 ELSE 0 END)
                                                    AS mid_installment_orders,
        SUM(CASE WHEN payment_installments > 6  THEN 1 ELSE 0 END)
                                                    AS high_installment_orders,

        -- Revenue on these orders
        ROUND(SUM(price), 2)                        AS total_item_revenue,
        ROUND(AVG(CAST(review_score AS FLOAT)), 2)  AS avg_review_score

    FROM dbo.vw_orders_staging
    WHERE payment_type IS NOT NULL
    GROUP BY payment_type
),
totals AS (
    SELECT SUM(total_orders) AS grand_total_orders
    FROM base
)
SELECT
    b.*,
    ROUND(b.total_orders * 100.0
          / t.grand_total_orders, 2)                AS pct_of_total_orders,
    ROUND(b.single_payment_orders * 100.0
          / NULLIF(b.total_orders, 0), 2)           AS single_payment_pct,
    ROUND(b.high_installment_orders * 100.0
          / NULLIF(b.total_orders, 0), 2)           AS high_installment_pct
FROM base b
CROSS JOIN totals t;
GO

PRINT 'View created: dbo.vw_payment_analysis';
