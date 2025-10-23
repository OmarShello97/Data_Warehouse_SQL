/*
============================================================
PRODUCT PERFORMANCE REPORT - MySQL Version
============================================================
*/

USE DataWarehouseAnalytics;

-- Drop view if exists
DROP VIEW IF EXISTS gold_report_products;

-- Create view
CREATE VIEW gold_report_products AS
WITH product_base_metrics AS (
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost,
        COUNT(DISTINCT s.order_number) AS total_orders,
        COUNT(DISTINCT s.customer_key) AS total_customers,
        SUM(s.sales_amount) AS total_sales,
        AVG(s.sales_amount) AS avg_sales,
        SUM(s.quantity) AS total_quantity,
        MIN(s.order_date) AS first_sale_date,
        MAX(s.order_date) AS last_sale_date,
        TIMESTAMPDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) AS lifespan_months,
        TIMESTAMPDIFF(MONTH, MAX(s.order_date), CURDATE()) AS recency_months,
        ROUND(AVG(s.sales_amount / NULLIF(s.quantity, 0)), 2) AS avg_selling_price,
        MIN(s.price) AS min_selling_price,
        MAX(s.price) AS max_selling_price
    FROM gold_fact_sales s
    LEFT JOIN gold_dim_products p ON s.product_key = p.product_key
    GROUP BY p.product_key, p.product_name, p.category, p.subcategory, p.cost
)
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost AS product_cost,
    CASE 
        WHEN cost < 100 THEN 'Below 100'
        WHEN cost BETWEEN 100 AND 499 THEN '100-499'
        WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
        ELSE 'Above 1000'
    END AS cost_range,
    first_sale_date,
    last_sale_date,
    recency_months,
    lifespan_months,
    CASE 
        WHEN total_sales < 200000 THEN 'Low Performance'
        WHEN total_sales BETWEEN 200000 AND 749999 THEN 'Mid Range'
        WHEN total_sales >= 750000 THEN 'High Performance'
    END AS performance_segment,
    CASE
        WHEN recency_months <= 3 THEN 'Active'
        WHEN recency_months BETWEEN 4 AND 6 THEN 'At Risk'
        WHEN recency_months BETWEEN 7 AND 12 THEN 'Dormant'
        ELSE 'Inactive'
    END AS recency_status,
    total_orders,
    total_customers,
    total_quantity,
    total_sales,
    ROUND(total_sales / NULLIF(SUM(total_sales) OVER(), 0) * 100, 2) AS sales_percentage,
    avg_sales AS avg_transaction_value,
    ROUND(total_sales / NULLIF(total_orders, 0), 2) AS avg_order_revenue,
    ROUND(total_sales / NULLIF(lifespan_months, 0), 2) AS avg_monthly_revenue,
    ROUND(total_orders / NULLIF(total_customers, 0), 2) AS avg_orders_per_customer,
    avg_selling_price,
    min_selling_price,
    max_selling_price,
    ROUND(avg_selling_price - cost, 2) AS avg_profit_margin,
    ROUND((avg_selling_price - cost) / NULLIF(cost, 0) * 100, 2) AS profit_margin_pct,
    CASE
        WHEN total_sales >= 750000 AND recency_months <= 3 THEN 'Excellent'
        WHEN total_sales >= 200000 AND recency_months <= 6 THEN 'Good'
        WHEN total_sales >= 200000 OR recency_months <= 6 THEN 'Fair'
        ELSE 'Poor'
    END AS product_health_score,
    DENSE_RANK() OVER(PARTITION BY category ORDER BY total_sales DESC) AS category_revenue_rank,
    DENSE_RANK() OVER(ORDER BY total_sales DESC) AS overall_revenue_rank
FROM product_base_metrics;