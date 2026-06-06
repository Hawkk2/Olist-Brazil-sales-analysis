-- =============================================================
-- Olist Brazil E-Commerce: Data Quality Checks & Migration
-- Database: BrazilOlistDB
-- Platform: T-SQL (SQL Server)
-- Run order: 3 of 4 (after schema creation + CSV import)
-- =============================================================

USE BrazilOlistDB;
GO

-- =============================================================
-- SECTION 1: Confirm imported column names and data types
-- =============================================================

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
      'olist_customers_dataset',
      'olist_sellers_dataset',
      'olist_products_dataset',
      'olist_orders_dataset',
      'olist_order_items_dataset',
      'olist_order_payments_dataset',
      'olist_order_reviews_dataset',
      'olist_geolocation_dataset',
      'product_category_name_translation_dataset'
  )
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO

-- =============================================================
-- SECTION 2: Migration — _dataset tables → typed tables
-- Deletes in child-first FK order, then inserts with casting.
-- Safe to re-run at any time.
-- =============================================================

-- Step 1: Clear typed tables in child-first order
DELETE FROM dbo.olist_order_reviews;
DELETE FROM dbo.olist_order_payments;
DELETE FROM dbo.olist_order_items;
DELETE FROM dbo.olist_orders;
DELETE FROM dbo.olist_products;
DELETE FROM dbo.product_category_name_translation;
DELETE FROM dbo.olist_sellers;
DELETE FROM dbo.olist_customers;
DELETE FROM dbo.olist_geolocation;
GO

-- -------------------------------------------------------
-- Customers
-- -------------------------------------------------------
INSERT INTO dbo.olist_customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
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
INSERT INTO dbo.olist_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
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
-- column1 = product_category_name (Portuguese)
-- column2 = product_category_name_english
-- -------------------------------------------------------
INSERT INTO dbo.product_category_name_translation (
    product_category_name,
    product_category_name_english
)
SELECT
    TRIM(column1),
    TRIM(column2)
FROM dbo.product_category_name_translation_dataset
WHERE column1 IS NOT NULL AND column1 <> '';

PRINT CONCAT('Category translations loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Products
-- -------------------------------------------------------
INSERT INTO dbo.olist_products (
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
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
-- Orders (load before items, payments, reviews)
-- -------------------------------------------------------
INSERT INTO dbo.olist_orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
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
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    TRIM(i.order_id),
    TRY_CAST(i.order_item_id   AS TINYINT),
    TRIM(i.product_id),
    TRIM(i.seller_id),
    TRY_CONVERT(DATETIME, i.shipping_limit_date),
    TRY_CAST(i.price           AS DECIMAL(10,2)),
    TRY_CAST(i.freight_value   AS DECIMAL(10,2))
FROM dbo.olist_order_items_dataset i
JOIN dbo.olist_orders o
    ON TRIM(i.order_id) = o.order_id
WHERE i.order_id IS NOT NULL AND i.order_id <> '';

PRINT CONCAT('Order items loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Order Payments
-- -------------------------------------------------------
INSERT INTO dbo.olist_order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    TRIM(p.order_id),
    TRY_CAST(p.payment_sequential   AS TINYINT),
    TRIM(p.payment_type),
    TRY_CAST(p.payment_installments AS TINYINT),
    TRY_CAST(p.payment_value        AS DECIMAL(10,2))
FROM dbo.olist_order_payments_dataset p
JOIN dbo.olist_orders o
    ON TRIM(p.order_id) = o.order_id
WHERE p.order_id IS NOT NULL AND p.order_id <> '';

PRINT CONCAT('Order payments loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Order Reviews
-- -------------------------------------------------------
-- The reviews dataset has duplicate review_ids (customer resubmissions).
-- ROW_NUMBER deduplicates, keeping the most recent submission per review_id.
INSERT INTO dbo.olist_order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM (
    SELECT
        TRIM(r.review_id)                                AS review_id,
        TRIM(r.order_id)                                 AS order_id,
        TRY_CAST(r.review_score           AS TINYINT)    AS review_score,
        NULLIF(TRIM(r.review_comment_title),   '')       AS review_comment_title,
        NULLIF(TRIM(r.review_comment_message), '')       AS review_comment_message,
        TRY_CONVERT(DATETIME, r.review_creation_date)    AS review_creation_date,
        TRY_CONVERT(DATETIME, r.review_answer_timestamp) AS review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(r.review_id)
            ORDER BY TRY_CONVERT(DATETIME, r.review_answer_timestamp) DESC
        ) AS rn
    FROM dbo.olist_order_reviews_dataset r
    JOIN dbo.olist_orders o
        ON TRIM(r.order_id) = o.order_id
    WHERE r.review_id IS NOT NULL AND r.review_id <> ''
) deduped
WHERE rn = 1;

PRINT CONCAT('Order reviews loaded: ', @@ROWCOUNT);

-- -------------------------------------------------------
-- Geolocation (no FK constraints)
-- -------------------------------------------------------
INSERT INTO dbo.olist_geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    TRIM(geolocation_zip_code_prefix),
    TRY_CAST(geolocation_lat   AS DECIMAL(18,15)),
    TRY_CAST(geolocation_lng   AS DECIMAL(18,15)),
    TRIM(geolocation_city),
    UPPER(TRIM(geolocation_state))
FROM dbo.olist_geolocation_dataset
WHERE geolocation_zip_code_prefix IS NOT NULL
  AND geolocation_zip_code_prefix <> '';

PRINT CONCAT('Geolocation rows loaded: ', @@ROWCOUNT);
GO

-- -------------------------------------------------------
-- Row count verification — compare against _dataset tables
-- -------------------------------------------------------
SELECT 'olist_customers'             AS tbl, COUNT(*) AS row_cnt FROM dbo.olist_customers
UNION ALL SELECT 'olist_sellers',             COUNT(*) FROM dbo.olist_sellers
UNION ALL SELECT 'olist_products',            COUNT(*) FROM dbo.olist_products
UNION ALL SELECT 'category_translation',      COUNT(*) FROM dbo.product_category_name_translation
UNION ALL SELECT 'olist_orders',              COUNT(*) FROM dbo.olist_orders
UNION ALL SELECT 'olist_order_items',         COUNT(*) FROM dbo.olist_order_items
UNION ALL SELECT 'olist_order_payments',      COUNT(*) FROM dbo.olist_order_payments
UNION ALL SELECT 'olist_order_reviews',       COUNT(*) FROM dbo.olist_order_reviews
UNION ALL SELECT 'olist_geolocation',         COUNT(*) FROM dbo.olist_geolocation
ORDER BY tbl;
GO

-- =============================================================
-- SECTION 3: Master Staging View
-- Joins all 9 tables into a single flat view with derived cols.
-- All reporting views in 03_views/ build on top of this.
-- =============================================================

IF OBJECT_ID('dbo.vw_orders_staging', 'V') IS NOT NULL
    DROP VIEW dbo.vw_orders_staging;
GO

CREATE VIEW dbo.vw_orders_staging AS
SELECT
    -- Order identifiers & status
    o.order_id,
    o.order_status,

    -- Timestamps
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- Derived date fields for Tableau
    CAST(o.order_purchase_timestamp AS DATE)        AS order_date,
    YEAR(o.order_purchase_timestamp)                AS order_year,
    MONTH(o.order_purchase_timestamp)               AS order_month,
    DATEFROMPARTS(
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp), 1)       AS order_month_start,

    -- Delivery performance
    DATEDIFF(DAY,
        o.order_purchase_timestamp,
        o.order_estimated_delivery_date)            AS estimated_delivery_days,

    DATEDIFF(DAY,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date)            AS actual_delivery_days,

    DATEDIFF(DAY,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date)            AS delivery_delay_days,

    CASE
        WHEN o.order_delivered_customer_date IS NULL             THEN 'Not Delivered'
        WHEN o.order_delivered_customer_date
           <= o.order_estimated_delivery_date                    THEN 'On Time'
        ELSE                                                          'Late'
    END                                             AS delivery_status,

    -- Customer
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,

    -- Product
    i.product_id,
    p.product_category_name                         AS product_category_pt,
    COALESCE(t.product_category_name_english,
             'Uncategorized')                       AS product_category_en,
    p.product_weight_g,

    -- Seller
    i.seller_id,
    s.seller_city,
    s.seller_state,

    -- Line item financials
    i.order_item_id,
    i.price,
    i.freight_value,
    i.price + i.freight_value                       AS total_item_value,
    i.price - i.freight_value                       AS contribution_margin,

    CASE
        WHEN i.price = 0 THEN 0
        ELSE ROUND((i.price - i.freight_value)
                   / i.price * 100, 2)
    END                                             AS contribution_margin_pct,

    -- Payment (primary payment per order)
    pay.payment_type,
    pay.payment_installments,
    pay.payment_value,

    -- Review
    r.review_score,
    CASE
        WHEN r.review_score >= 4 THEN 'Positive'
        WHEN r.review_score  = 3 THEN 'Neutral'
        WHEN r.review_score <= 2 THEN 'Negative'
        ELSE                          'No Review'
    END                                             AS review_sentiment

FROM      dbo.olist_orders               o
JOIN      dbo.olist_customers            c   ON o.customer_id  = c.customer_id
JOIN      dbo.olist_order_items          i   ON o.order_id     = i.order_id
JOIN      dbo.olist_products             p   ON i.product_id   = p.product_id
JOIN      dbo.olist_sellers              s   ON i.seller_id    = s.seller_id
LEFT JOIN dbo.product_category_name_translation t
                                             ON p.product_category_name
                                              = t.product_category_name
LEFT JOIN dbo.olist_order_reviews        r   ON o.order_id     = r.order_id
LEFT JOIN (
    SELECT order_id, payment_type, payment_installments, payment_value
    FROM   dbo.olist_order_payments
    WHERE  payment_sequential = 1
)                                        pay ON o.order_id     = pay.order_id
WHERE o.order_status = 'delivered';
GO

PRINT 'vw_orders_staging created successfully.';
PRINT 'Next: run sql/03_views/ files to build reporting views.';


-- =============================================================
-- SECTION 4: Analysis of created tables and views. 
-- =============================================================

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
      'olist_customers',
      'olist_sellers',
      'olist_products',
      'olist_orders',
      'olist_order_items',
      'olist_order_payments',
      'olist_order_reviews',
      'olist_geolocation',
      'product_category_name_translation'
  )
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO

-- -------------------------------------------------------
-- Confirm all 9 typed tables exist and their row counts
-- -------------------------------------------------------

SELECT
    t.TABLE_NAME,
    p.rows AS row_count
FROM INFORMATION_SCHEMA.TABLES t
JOIN sys.partitions p
    ON p.object_id = OBJECT_ID('dbo.' + t.TABLE_NAME)
WHERE t.TABLE_SCHEMA = 'dbo'
  AND t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_NAME NOT LIKE '%_dataset'
  AND p.index_id IN (0, 1)
ORDER BY t.TABLE_NAME;

-- -------------------------------------------------------
-- Confirm main view exist, vw_orders_staging.  8 derived views in next file.
-- -------------------------------------------------------

SELECT
    TABLE_NAME  AS view_name
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME;

-- -------------------------------------------------------
-- Quick data spot-check — first 5 rows from each core table
-- -------------------------------------------------------

SELECT TOP 5 * FROM dbo.olist_customers;
SELECT TOP 5 * FROM dbo.olist_sellers;
SELECT TOP 5 * FROM dbo.olist_products;
SELECT TOP 5 * FROM dbo.product_category_name_translation;
SELECT TOP 5 * FROM dbo.olist_orders;
SELECT TOP 5 * FROM dbo.olist_order_items;
SELECT TOP 5 * FROM dbo.olist_order_payments;
SELECT TOP 5 * FROM dbo.olist_order_reviews;
SELECT TOP 5 * FROM dbo.olist_geolocation;


-- -------------------------------------------------------
-- Confirm  view return data (not broken)
-- -------------------------------------------------------

SELECT TOP 3 * FROM dbo.vw_orders_staging;

-- -------------------------------------------------------
-- Confirm Sanity check — typed tables vs. dataset tables row counts match
-- -------------------------------------------------------

SELECT 'customers'    AS tbl, COUNT(*) AS typed FROM dbo.olist_customers         UNION ALL
SELECT 'sellers',              COUNT(*)          FROM dbo.olist_sellers            UNION ALL
SELECT 'products',             COUNT(*)          FROM dbo.olist_products           UNION ALL
SELECT 'translations',         COUNT(*)          FROM dbo.product_category_name_translation UNION ALL
SELECT 'orders',               COUNT(*)          FROM dbo.olist_orders             UNION ALL
SELECT 'order_items',          COUNT(*)          FROM dbo.olist_order_items        UNION ALL
SELECT 'order_payments',       COUNT(*)          FROM dbo.olist_order_payments     UNION ALL
SELECT 'order_reviews',        COUNT(*)          FROM dbo.olist_order_reviews      UNION ALL
SELECT 'geolocation',          COUNT(*)          FROM dbo.olist_geolocation;
