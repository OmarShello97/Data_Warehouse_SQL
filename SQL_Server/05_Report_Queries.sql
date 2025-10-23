USE DataWarehouseAnalytics;
GO

-- ============================================================
-- REPORT VIEWS - QUERY EXECUTION
-- ============================================================
-- Purpose: Execute the analytical views created for reporting
-- ============================================================

-- Products performance report
SELECT * FROM gold.report_products
ORDER BY total_sales DESC;

-- Customer analytics report
SELECT * FROM gold.report_customers
ORDER BY customer_lifetime_value DESC;