-- =============================================================
-- Olist Brazil E-Commerce: Data Quality Checks & Migration
-- Database: BrazilOlistDB
-- Platform: T-SQL (SQL Server)
-- Description: Section 1 runs quality checks against the raw
--              _dataset tables imported via SSMS wizard.
--              Section 2 migrates data into the properly-typed
--              tables created by 01_schema/create_tables.sql.
--              Section 3 creates the master staging view.
-- Run order: 3 of 4 (after schema + CSV import)
-- =============================================================

USE BrazilOlistDB;
GO

-- =============================================================
-- SECTION 1: Data Quality Checks
-- Run these first. Review output before proceeding to Section 2.
-- =============================================================

-- 1a. Row counts across all imported tables
SELECT 'olist_customers_dataset'                AS TableName, COUNT(*) AS RowCount FROM dbo.olist_customers_dataset
UNION ALL SELECT 'olist_sellers_dataset',                     COUNT(*) FROM dbo.olist_sellers_dataset
UNION ALL SELECT 'olist_products_dataset',                    COUNT(*) FROM dbo.olist_products_dataset
UNION ALL SELECT 'olist_orders_dataset',                      COUNT(*) FROM dbo.olist_orders_dataset
UNION ALL SELECT 'olist_order_items_dataset',                 COUNT(*) FROM dbo.olist_order_items_dataset
UNION ALL SELECT 'olist_order_payments_dataset',              COUNT(*) FROM dbo.olist_order_payments_dataset
UNION ALL SELECT 'olist_order_reviews_dataset',               COUNT(*) FROM dbo.olist_order_reviews_dataset
UNION ALL SELECT 'olist_geolocation_dataset',                 COUNT(*) FROM dbo.olist_geolocation_dataset
UNION ALL SELECT 'product_category_name_translation_dataset', COUNT(*) FROM dbo.product_category_name_translation_dataset;

-- 1b. Order status distribution
SELECT order_status, COUNT(*) AS OrderCount
FROM dbo.olist_orders_dataset
GROUP BY order_status
ORDER BY OrderCount DESC;

-- 1c. Date range check — confirm 2016–2018 range
SELECT
    MIN(order_purchase_timestamp)   AS EarliestOrder,
    MAX(order_purchase_timestamp)   AS LatestOrder
FROM dbo.olist_orders_dataset;

-- 1d. Null check on order items (price and freight are critical)
SELECT
    SUM(CASE WHEN price         IS NULL OR price = ''         THEN 1 ELSE 0 END) AS NullPrice,
    SUM(CASE WHEN freight_value IS NULL OR freight_value = '' THEN 1 ELSE 0 END) AS NullFreight,
    SUM(CASE WHEN product_id    IS NULL OR product_id = ''    THEN 1 ELSE 0 END) AS NullProductID,
    SUM(CASE WHEN seller_id     IS NULL OR seller_id = ''     THEN 1 ELSE 0 END) AS NullSellerID
FROM dbo.olist_order_items_dataset;

-- 1e. Review score distribution (expect 1–5 only)
SELECT review_score, COUNT(*) AS ReviewCount
FROM dbo.olist_order_reviews_dataset
GROUP BY review_score
ORDER BY review_score;

-- 1f. Payment type distribution
SELECT payment_type, COUNT(*) AS PaymentCount
FROM dbo.olist_order_payments_dataset
GROUP BY payment_type
ORDER BY PaymentCount DESC;

-- 1g. Products with no category (will show as 'Uncategorized')
SELECT COUNT(*) AS ProductsWithNoCategory
FROM dbo.olist_products_dataset
WHERE product_category_name IS NULL OR product_category_name = '';

-- 1h. Orders with no matching items (orphaned orders)
SELECT COUNT(*) AS OrdersWithNoItems
FROM dbo.olist_orders_dataset o
LEFT JOIN dbo.olist_order_items_dataset i ON o.order_id = i.order_id
WHERE i.order_id IS NULL;

GO

-- =============================================================
-- SECTION 2: Migration — _dataset tables → typed tables
-- Casts nvarchar columns to correct data types.
-- Safe to re-run: truncates destination tables first.
-- =============================================================

-- -------------------------------------------------------
-- Customers
-- -------------------------------------------------------
TRUNCATE TABLE dbo.olist_customers;

INSERT INTO dbo.olist_customers (
    customer_id, customer_unique_id, customer_zip_code_prefix,
    customer_city, customer_state
)
SELECT
    TRIM(customer_id),
    TRIM(customer_unique_id),
    TRIM(customer_zip_code_prefix),
    TRIM(customer_city),
    UPPER(TRIM(customer_state))
FROM dbo.olist_customers_dataset
WHERE customer_id IS NOT NULL AND customer_id <> '';

PRINT CONCAT('Customers loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Sellers
-- -------------------------------------------------------
TRUNCATE TABLE dbo.olist_sellers;

INSERT INTO dbo.olist_sellers (
    seller_id, seller_zip_code_prefix, seller_city, seller_state
)
SELECT
    TRIM(seller_id),
    TRIM(seller_zip_code_prefix),
    TRIM(seller_city),
    UPPER(TRIM(seller_state))
FROM dbo.olist_sellers_dataset
WHERE seller_id IS NOT NULL AND seller_id <> '';

PRINT CONCAT('Sellers loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Category Translation
-- -------------------------------------------------------
TRUNCATE TABLE dbo.product_category_name_translation;

INSERT INTO dbo.product_category_name_translation (
    product_category_name, product_category_name_english
)
SELECT
    TRIM(product_category_name),
    TRIM(product_category_name_english)
FROM dbo.product_category_name_translation_dataset
WHERE product_category_name IS NOT NULL AND product_category_name <> '';

PRINT CONCAT('Category translations loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Products
-- -------------------------------------------------------
TRUNCATE TABLE dbo.olist_products;

INSERT INTO dbo.olist_products (
    product_id, product_category_name,
    product_name_lenght, product_description_lenght,
    product_photos_qty, product_weight_g,
    product_length_cm, product_height_cm, product_width_cm
)
SELECT
    TRIM(product_id),
    NULLIF(TRIM(product_category_name), ''),
    TRY_CAST(product_name_lenght        AS SMALLINT),
    TRY_CAST(product_description_lenght AS SMALLINT),
    TRY_CAST(product_photos_qty         AS TINYINT),
    TRY_CAST(product_weight_g           AS INT),
    TRY_CAST(product_length_cm          AS SMALLINT),
    TRY_CAST(product_height_cm          AS SMALLINT),
    TRY_CAST(product_width_cm           AS SMALLINT)
FROM dbo.olist_products_dataset
WHERE product_id IS NOT NULL AND product_id <> '';

PRINT CONCAT('Products loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Orders (load after customers due to FK)
-- -------------------------------------------------------
TRUNCATE TABLE dbo.olist_order_reviews;    -- child tables first
TRUNCATE TABLE dbo.olist_order_payments;
TRUNCATE TABLE dbo.olist_order_items;
TRUNCATE TABLE dbo.olist_orders;

INSERT INTO dbo.olist_orders (
    order_id, customer_id, order_status,
    order_purchase_timestamp, order_approved_at,
    order_delivered_carrier_date, order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    TRIM(order_id),
    TRIM(customer_id),
    TRIM(order_status),
    TRY_CONVERT(DATETIME, order_purchase_timestamp),
    TRY_CONVERT(DATETIME, order_approved_at),
    TRY_CONVERT(DATETIME, order_delivered_carrier_date),
    TRY_CONVERT(DATETIME, order_delivered_customer_date),
    TRY_CONVERT(DATETIME, order_estimated_delivery_date)
FROM dbo.olist_orders_dataset
WHERE order_id IS NOT NULL AND order_id <> '';

PRINT CONCAT('Orders loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Order Items
-- -------------------------------------------------------
INSERT INTO dbo.olist_order_items (
    order_id, order_item_id, product_id, seller_id,
    shipping_limit_date, price, freight_value
)
SELECT
    TRIM(order_id),
    TRY_CAST(order_item_id AS TINYINT),
    TRIM(product_id),
    TRIM(seller_id),
    TRY_CONVERT(DATETIME, shipping_limit_date),
    TRY_CAST(price         AS DECIMAL(10,2)),
    TRY_CAST(freight_value AS DECIMAL(10,2))
FROM dbo.olist_order_items_dataset
WHERE order_id IS NOT NULL AND order_id <> ''
  AND EXISTS (SELECT 1 FROM dbo.olist_orders WHERE order_id = TRIM(dbo.olist_order_items_dataset.order_id));

PRINT CONCAT('Order items loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Order Payments
-- -------------------------------------------------------
INSERT INTO dbo.olist_order_payments (
    order_id, payment_sequential, payment_type,
    payment_installments, payment_value
)
SELECT
    TRIM(order_id),
    TRY_CAST(payment_sequential   AS TINYINT),
    TRIM(payment_type),
    TRY_CAST(payment_installments AS TINYINT),
    TRY_CAST(payment_value        AS DECIMAL(10,2))
FROM dbo.olist_order_payments_dataset
WHERE order_id IS NOT NULL AND order_id <> ''
  AND EXISTS (SELECT 1 FROM dbo.olist_orders WHERE order_id = TRIM(dbo.olist_order_payments_dataset.order_id));

PRINT CONCAT('Order payments loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Order Reviews
-- -------------------------------------------------------
INSERT INTO dbo.olist_order_reviews (
    review_id, order_id, review_score,
    review_comment_title, review_comment_message,
    review_creation_date, review_answer_timestamp
)
SELECT
    TRIM(review_id),
    TRIM(order_id),
    TRY_CAST(review_score AS TINYINT),
    NULLIF(TRIM(review_comment_title),   ''),
    NULLIF(TRIM(review_comment_message), ''),
    TRY_CONVERT(DATETIME, review_creation_date),
    TRY_CONVERT(DATETIME, review_answer_timestamp)
FROM dbo.olist_order_reviews_dataset
WHERE review_id IS NOT NULL AND review_id <> ''
  AND EXISTS (SELECT 1 FROM dbo.olist_orders WHERE order_id = TRIM(dbo.olist_order_reviews_dataset.order_id));

PRINT CONCAT('Order reviews loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Geolocation (no FK — load independently)
-- -------------------------------------------------------
TRUNCATE TABLE dbo.olist_geolocation;

INSERT INTO dbo.olist_geolocation (
    geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
    geolocation_city, geolocation_state
)
SELECT
    TRIM(geolocation_zip_code_prefix),
    TRY_CAST(geolocation_lat  AS DECIMAL(18,15)),
    TRY_CAST(geolocation_lng  AS DECIMAL(18,15)),
    TRIM(geolocation_city),
    UPPER(TRIM(geolocation_state))
FROM dbo.olist_geolocation_dataset
WHERE geolocation_zip_code_prefix IS NOT NULL
  AND geolocation_zip_code_prefix <> '';

PRINT CONCAT('Geolocation rows loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Post-migration row count verification
-- -------------------------------------------------------
SELECT 'olist_customers'                    AS TableName, COUNT(*) AS RowCount FROM dbo.olist_customers
UNION ALL SELECT 'olist_sellers',                          COUNT(*) FROM dbo.olist_sellers
UNION ALL SELECT 'olist_products',                         COUNT(*) FROM dbo.olist_products
UNION ALL SELECT 'olist_orders',                           COUNT(*) FROM dbo.olist_orders
UNION ALL SELECT 'olist_order_items',                      COUNT(*) FROM dbo.olist_order_items
UNION ALL SELECT 'olist_order_payments',                   COUNT(*) FROM dbo.olist_order_payments
UNION ALL SELECT 'olist_order_reviews',                    COUNT(*) FROM dbo.olist_order_reviews
UNION ALL SELECT 'olist_geolocation',                      COUNT(*) FROM dbo.olist_geolocation
UNION ALL SELECT 'product_category_name_translation',      COUNT(*) FROM dbo.product_category_name_translation;
GO

-- =============================================================
-- SECTION 3: Master Staging View
-- Single source of truth for all reporting views.
-- Joins all tables, adds derived columns, translates categories.
-- =============================================================

IF OBJECT_ID('dbo.vw_orders_staging', 'V') IS NOT NULL
    DROP VIEW dbo.vw_orders_staging;
GO

CREATE VIEW dbo.vw_orders_staging AS
SELECT
    -- Order identifiers
    o.order_id,
    o.order_status,

    -- Timestamps
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- Derived date fields
    CAST(o.order_purchase_timestamp AS DATE)            AS order_date,
    YEAR(o.order_purchase_timestamp)                    AS order_year,
    MONTH(o.order_purchase_timestamp)                   AS order_month,
    DATEFROMPARTS(
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp), 1)           AS order_month_start,

    -- Delivery performance (days)
    DATEDIFF(DAY,
        o.order_purchase_timestamp,
        o.order_estimated_delivery_date)                AS estimated_delivery_days,

    DATEDIFF(DAY,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date)                AS actual_delivery_days,

    DATEDIFF(DAY,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date)                AS delivery_delay_days,  -- negative = early, positive = late

    CASE
        WHEN o.order_delivered_customer_date IS NULL        THEN 'Not Delivered'
        WHEN o.order_delivered_customer_date
           <= o.order_estimated_delivery_date              THEN 'On Time'
        ELSE                                                     'Late'
    END                                                 AS delivery_status,

    -- Customer
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,

    -- Product
    i.product_id,
    p.product_category_name                             AS product_category_pt,
    COALESCE(t.product_category_name_english, 'Uncategorized')
                                                        AS product_category_en,
    p.product_weight_g,

    -- Seller
    i.seller_id,
    s.seller_city,
    s.seller_state,

    -- Order item details
    i.order_item_id,
    i.price,
    i.freight_value,
    i.price + i.freight_value                           AS total_item_value,
    i.price - i.freight_value                           AS contribution_margin,  -- revenue minus freight cost

    CASE WHEN i.price = 0 THEN 0
         ELSE ROUND((i.price - i.freight_value) / i.price * 100, 2)
    END                                                 AS contribution_margin_pct,

    -- Payment (aggregated per order — one row per item so payment is repeated)
    pay.payment_type,
    pay.payment_installments,
    pay.payment_value,

    -- Review
    r.review_score,
    CASE
        WHEN r.review_score >= 4 THEN 'Positive'
        WHEN r.review_score = 3  THEN 'Neutral'
        WHEN r.review_score <= 2 THEN 'Negative'
        ELSE                          'No Review'
    END                                                 AS review_sentiment

FROM dbo.olist_orders           o
JOIN  dbo.olist_customers       c   ON o.customer_id   = c.customer_id
JOIN  dbo.olist_order_items     i   ON o.order_id      = i.order_id
JOIN  dbo.olist_products        p   ON i.product_id    = p.product_id
JOIN  dbo.olist_sellers         s   ON i.seller_id     = s.seller_id
LEFT JOIN dbo.product_category_name_translation t
                                    ON p.product_category_name = t.product_category_name
LEFT JOIN dbo.olist_order_reviews r ON o.order_id      = r.order_id
LEFT JOIN (
    -- Take the primary payment per order (sequential = 1)
    SELECT order_id, payment_type, payment_installments, payment_value
    FROM dbo.olist_order_payments
    WHERE payment_sequential = 1
) pay                               ON o.order_id      = pay.order_id

WHERE o.order_status = 'delivered';  -- focus analysis on completed orders
GO

PRINT 'Master staging view created: dbo.vw_orders_staging';
PRINT 'Next step: run sql/03_views/ files to build reporting views.';
