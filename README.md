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
- [x] Import all 9 CSV files into SQL Server

### Phase 2 — Data Quality & Staging
- [x] Run data quality checks on all tables
- [x] Build master staging view with joins and derived columns
- [x] Translate product categories (Portuguese → English)
