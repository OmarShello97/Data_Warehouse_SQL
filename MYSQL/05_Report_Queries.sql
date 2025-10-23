USE DataWarehouseAnalytics;

-- ============================================================
-- REPORT VIEWS - QUERY EXECUTION - MySQL Version
-- ============================================================

-- Products performance report
SELECT * 
FROM gold_report_products
ORDER BY total_sales DESC;

-- Customer analytics report
SELECT * 
FROM gold_report_customers
ORDER BY customer_lifetime_value DESC;