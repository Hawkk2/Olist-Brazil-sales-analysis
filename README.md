# Olist Brazil E-Commerce Sales Analysis

An end-to-end data analytics portfolio project analyzing 100,000+ real e-commerce orders from Olist, Brazil's largest online marketplace aggregator (2016–2018).

**Focus:** Revenue & profitability by product category, seller, and state — plus delivery performance analysis comparing actual vs. estimated delivery dates.

---

## Tech Stack

![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![Tableau](https://img.shields.io/badge/Tableau-Public-E97627?style=flat&logo=tableau&logoColor=white)
![SSMS](https://img.shields.io/badge/SSMS-Database%20IDE-0078D4?style=flat)

| Layer | Tool |
|---|---|
| Database & Querying | SQL Server (T-SQL) via SSMS |
| Data Visualization | Tableau Public |
| Version Control | Git / GitHub |

---

## Project Progress

### Phase 1 — Database Schema & Table Setup
- [x] Design normalized schema across 9 source tables
- [x] Write DDL with correct data types and indexes
- [ ] Import all 9 CSV files into SQL Server

### Phase 2 — Data Quality & Staging
- [ ] Run data quality checks on all tables
- [ ] Build master staging view with joins and derived columns
- [ ] Translate product categories (Portuguese → English)

### Phase 3 — Revenue & Profitability Views
- [ ] Revenue by product category
- [ ] Revenue and freight margin by seller state
- [ ] Top and bottom seller performance
- [ ] Monthly revenue trends with MoM growth
- [ ] Payment method breakdown

### Phase 4 — Delivery Performance Views
- [ ] Actual vs. estimated delivery date analysis
- [ ] Delivery delay by product category
- [ ] Delivery delay by seller state
- [ ] On-time delivery rate by seller

### Phase 5 — Tableau Dashboard: Sales & Profitability
- [ ] Executive KPI summary sheet
- [ ] Revenue by category treemap
- [ ] State-level revenue map
- [ ] Monthly trend line chart
- [ ] Payment type breakdown

### Phase 6 — Tableau Dashboard: Delivery Performance
- [ ] On-time vs. late delivery overview
- [ ] Avg delay by state map
- [ ] Category-level delivery heatmap
- [ ] Seller delivery scorecard

### Phase 7 — Insights & Documentation
- [ ] Key findings writeup
- [ ] Business recommendations
- [ ] README final polish

---

## Dataset

**Source:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — Kaggle  
**License:** CC BY-NC-SA 4.0  
**Size:** ~100,000 orders | 2016–2018 | 9 relational CSV files  
**Usability Score:** 10.0 / 10.0 on Kaggle

> Real anonymized commercial data. Company and partner names in reviews were replaced with Game of Thrones house names per Olist's anonymization protocol.

---

## Schema Overview

```
olist_customers ──────────────────────────────┐
                                              │
olist_orders (central) ───── order_id ────────┤
    │                                         │
    ├── olist_order_items ─── product_id ──── olist_products
    │        │                                     │
    │        └── seller_id ─────────────── olist_sellers
    │
    ├── olist_order_payments
    ├── olist_order_reviews
    └── (geolocation via zip code prefix)

product_category_name_translation
    └── maps Portuguese → English category names
```

---

## Setup Instructions

### 1. Prerequisites
- SQL Server (any edition) + SSMS
- Tableau Public (free)
- [Dataset CSV files from Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

### 2. Database Setup
```sql
CREATE DATABASE BrazilOlistDB;
```
Run scripts in order:
```
sql/01_schema/create_tables.sql
```
Then import each CSV using SSMS Import Wizard (**import all columns as nvarchar(255) first**).

### 3. Run Remaining SQL Scripts
```
sql/02_prep/clean_and_stage.sql
sql/03_views/  (all files)
sql/04_analysis/exec_summary_kpis.sql
```

### 4. Connect Tableau
Open Tableau Public → Connect to CSV files in the `exports/` folder.

---

*Project in progress — contributions added incrementally.*
