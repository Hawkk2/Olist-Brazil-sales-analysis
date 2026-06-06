-- =============================================================
-- Olist Brazil E-Commerce: Schema Creation
-- Database: BrazilOlistDB
-- Platform: T-SQL (SQL Server)
-- Description: Creates Database
--				Creates all 9 source tables matching the Olist
--              CSV structure. Run this before importing data.
--              Import all CSVs with columns set to nvarchar(255)
--              first — clean_and_stage.sql handles type casting.
-- Run order: 1 of 4
-- =============================================================

CREATE DATABASE BrazilOlistDB;

USE BrazilOlistDB;
GO

-- -------------------------------------------------------
-- Drop all tables in reverse dependency order
-- -------------------------------------------------------
IF OBJECT_ID('dbo.olist_geolocation',                   'U') IS NOT NULL DROP TABLE dbo.olist_geolocation;
IF OBJECT_ID('dbo.product_category_name_translation',   'U') IS NOT NULL DROP TABLE dbo.product_category_name_translation;
IF OBJECT_ID('dbo.olist_order_reviews',                 'U') IS NOT NULL DROP TABLE dbo.olist_order_reviews;
IF OBJECT_ID('dbo.olist_order_payments',                'U') IS NOT NULL DROP TABLE dbo.olist_order_payments;
IF OBJECT_ID('dbo.olist_order_items',                   'U') IS NOT NULL DROP TABLE dbo.olist_order_items;
IF OBJECT_ID('dbo.olist_orders',                        'U') IS NOT NULL DROP TABLE dbo.olist_orders;
IF OBJECT_ID('dbo.olist_products',                      'U') IS NOT NULL DROP TABLE dbo.olist_products;
IF OBJECT_ID('dbo.olist_sellers',                       'U') IS NOT NULL DROP TABLE dbo.olist_sellers;
IF OBJECT_ID('dbo.olist_customers',                     'U') IS NOT NULL DROP TABLE dbo.olist_customers;
GO

-- -------------------------------------------------------
-- Customers
-- -------------------------------------------------------
CREATE TABLE dbo.olist_customers (
    customer_id             VARCHAR(32)     NOT NULL,
    customer_unique_id      VARCHAR(32)     NOT NULL,
    customer_zip_code_prefix VARCHAR(10)   NOT NULL,
    customer_city           VARCHAR(100)    NOT NULL,
    customer_state          CHAR(2)         NOT NULL,

    CONSTRAINT PK_customers PRIMARY KEY (customer_id)
);
GO

-- -------------------------------------------------------
-- Sellers
-- -------------------------------------------------------
CREATE TABLE dbo.olist_sellers (
    seller_id               VARCHAR(32)     NOT NULL,
    seller_zip_code_prefix  VARCHAR(10)     NOT NULL,
    seller_city             VARCHAR(100)    NOT NULL,
    seller_state            CHAR(2)         NOT NULL,

    CONSTRAINT PK_sellers PRIMARY KEY (seller_id)
);
GO

-- -------------------------------------------------------
-- Products
-- -------------------------------------------------------
CREATE TABLE dbo.olist_products (
    product_id                      VARCHAR(32)     NOT NULL,
    product_category_name           VARCHAR(100)        NULL,   -- Portuguese; NULL for uncategorized
    product_name_lenght             SMALLINT            NULL,
    product_description_lenght      SMALLINT            NULL,   -- Note: intentional typo from source data
    product_photos_qty              TINYINT             NULL,
    product_weight_g                INT                 NULL,
    product_length_cm               SMALLINT            NULL,
    product_height_cm               SMALLINT            NULL,
    product_width_cm                SMALLINT            NULL,

    CONSTRAINT PK_products PRIMARY KEY (product_id)
);
GO

-- -------------------------------------------------------
-- Category Name Translation (Portuguese → English)
-- -------------------------------------------------------
CREATE TABLE dbo.product_category_name_translation (
    product_category_name           VARCHAR(100)    NOT NULL,
    product_category_name_english   VARCHAR(100)    NOT NULL,

    CONSTRAINT PK_category_translation PRIMARY KEY (product_category_name)
);
GO

-- -------------------------------------------------------
-- Orders (central table)
-- -------------------------------------------------------
CREATE TABLE dbo.olist_orders (
    order_id                        VARCHAR(32)     NOT NULL,
    customer_id                     VARCHAR(32)     NOT NULL,
    order_status                    VARCHAR(20)     NOT NULL,   -- delivered, shipped, canceled, etc.
    order_purchase_timestamp        DATETIME            NULL,
    order_approved_at               DATETIME            NULL,
    order_delivered_carrier_date    DATETIME            NULL,
    order_delivered_customer_date   DATETIME            NULL,
    order_estimated_delivery_date   DATETIME            NULL,

    CONSTRAINT PK_orders PRIMARY KEY (order_id),
    CONSTRAINT FK_orders_customers FOREIGN KEY (customer_id)
        REFERENCES dbo.olist_customers (customer_id)
);
GO

-- -------------------------------------------------------
-- Order Items (one row per item per order)
-- -------------------------------------------------------
CREATE TABLE dbo.olist_order_items (
    order_id                VARCHAR(32)     NOT NULL,
    order_item_id           TINYINT         NOT NULL,   -- sequence within the order (1, 2, 3...)
    product_id              VARCHAR(32)     NOT NULL,
    seller_id               VARCHAR(32)     NOT NULL,
    shipping_limit_date     DATETIME            NULL,
    price                   DECIMAL(10,2)   NOT NULL,
    freight_value           DECIMAL(10,2)   NOT NULL,

    CONSTRAINT PK_order_items PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT FK_items_orders   FOREIGN KEY (order_id)   REFERENCES dbo.olist_orders   (order_id),
    CONSTRAINT FK_items_products FOREIGN KEY (product_id) REFERENCES dbo.olist_products (product_id),
    CONSTRAINT FK_items_sellers  FOREIGN KEY (seller_id)  REFERENCES dbo.olist_sellers  (seller_id)
);
GO

-- -------------------------------------------------------
-- Order Payments (one row per payment method per order)
-- -------------------------------------------------------
CREATE TABLE dbo.olist_order_payments (
    order_id                VARCHAR(32)     NOT NULL,
    payment_sequential      TINYINT         NOT NULL,   -- multiple payments per order allowed
    payment_type            VARCHAR(20)     NOT NULL,   -- credit_card, boleto, voucher, debit_card
    payment_installments    TINYINT         NOT NULL,
    payment_value           DECIMAL(10,2)   NOT NULL,

    CONSTRAINT PK_payments PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT FK_payments_orders FOREIGN KEY (order_id) REFERENCES dbo.olist_orders (order_id)
);
GO

-- -------------------------------------------------------
-- Order Reviews (one review per order)
-- -------------------------------------------------------
CREATE TABLE dbo.olist_order_reviews (
    review_id               VARCHAR(32)     NOT NULL,
    order_id                VARCHAR(32)     NOT NULL,
    review_score            TINYINT         NOT NULL,   -- 1 to 5 stars
    review_comment_title    NVARCHAR(255)       NULL,
    review_comment_message  NVARCHAR(MAX)       NULL,
    review_creation_date    DATETIME            NULL,
    review_answer_timestamp DATETIME            NULL,

    CONSTRAINT PK_reviews PRIMARY KEY (review_id),
    CONSTRAINT FK_reviews_orders FOREIGN KEY (order_id) REFERENCES dbo.olist_orders (order_id)
);
GO

-- -------------------------------------------------------
-- Geolocation (zip code → lat/lng)
-- No FK — zip codes appear multiple times (one per data point)
-- -------------------------------------------------------
CREATE TABLE dbo.olist_geolocation (
    geolocation_zip_code_prefix VARCHAR(10)     NOT NULL,
    geolocation_lat             DECIMAL(18,15)  NOT NULL,
    geolocation_lng             DECIMAL(18,15)  NOT NULL,
    geolocation_city            VARCHAR(100)    NOT NULL,
    geolocation_state           CHAR(2)         NOT NULL
);
GO

-- -------------------------------------------------------
-- Indexes to support common join and filter patterns
-- -------------------------------------------------------
CREATE INDEX IX_orders_customer_id        ON dbo.olist_orders        (customer_id);
CREATE INDEX IX_orders_status             ON dbo.olist_orders        (order_status);
CREATE INDEX IX_orders_purchase_ts        ON dbo.olist_orders        (order_purchase_timestamp);
CREATE INDEX IX_items_product_id          ON dbo.olist_order_items   (product_id);
CREATE INDEX IX_items_seller_id           ON dbo.olist_order_items   (seller_id);
CREATE INDEX IX_payments_type             ON dbo.olist_order_payments(payment_type);
CREATE INDEX IX_reviews_score             ON dbo.olist_order_reviews (review_score);
CREATE INDEX IX_reviews_order_id          ON dbo.olist_order_reviews (order_id);
CREATE INDEX IX_products_category         ON dbo.olist_products      (product_category_name);
CREATE INDEX IX_customers_state           ON dbo.olist_customers     (customer_state);
CREATE INDEX IX_sellers_state             ON dbo.olist_sellers       (seller_state);
CREATE INDEX IX_geolocation_zip           ON dbo.olist_geolocation   (geolocation_zip_code_prefix);
GO

PRINT 'BrazilOlistDB schema created successfully — 9 tables, 12 indexes.';
PRINT 'Next step: Import each CSV using SSMS Import Wizard with all columns as nvarchar(255).';
PRINT 'Then run: sql/02_prep/clean_and_stage.sql';
