/*
============================================================
CUSTOMER ANALYTICS REPORT
============================================================
Purpose:
    Comprehensive customer-level analytics view ...
============================================================
*/

USE DataWarehouseAnalytics;

DROP VIEW IF EXISTS report_customers;

CREATE VIEW report_customers AS
WITH customer_transactions AS (
    SELECT
        s.order_number,
        s.product_key,
        s.order_date,
        s.sales_amount,
        s.quantity,
        s.price,
        c.customer_key,
        c.customer_number,
        c.first_name,
        c.last_name,
        CONCAT(c.first_name, ' ', c.last_name) AS full_name,
        c.country,
        c.gender,
        TIMESTAMPDIFF(YEAR, c.birthdate, CURRENT_DATE()) AS age,
        c.birthdate
    FROM gold_fact_sales s
    LEFT JOIN gold_dim_customers c ON s.customer_key = c.customer_key
    WHERE s.order_date IS NOT NULL
),
customer_metrics AS (
    SELECT
        customer_key,
        customer_number,
        first_name,
        last_name,
        full_name,
        country,
        gender,
        age,
        birthdate,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        AVG(sales_amount) AS avg_transaction_value,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months,
        TIMESTAMPDIFF(MONTH, MAX(order_date), CURRENT_DATE()) AS recency_months,
        TIMESTAMPDIFF(DAY, MAX(order_date), CURRENT_DATE()) AS recency_days,
        MAX(price) AS highest_price_paid,
        MIN(price) AS lowest_price_paid,
        AVG(price) AS avg_price_paid
    FROM customer_transactions
    GROUP BY 
        customer_key, customer_number, first_name, last_name, full_name,
        country, gender, age, birthdate
),
customer_segmented AS (
SELECT
    customer_key,
    customer_number,
    first_name,
    last_name,
    full_name,
    age,
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50+'
    END AS age_group,
    gender,
    country,
    birthdate,
    CASE 
        WHEN lifespan_months >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan_months >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    CASE
        WHEN recency_months <= 3 THEN 'Active'
        WHEN recency_months BETWEEN 4 AND 6 THEN 'At Risk'
        WHEN recency_months BETWEEN 7 AND 12 THEN 'Dormant'
        ELSE 'Churned'
    END AS engagement_status,
    CASE
        WHEN total_sales >= 10000 THEN 'High Value'
        WHEN total_sales BETWEEN 5000 AND 9999 THEN 'Medium Value'
        WHEN total_sales BETWEEN 1000 AND 4999 THEN 'Low Value'
        ELSE 'Entry Level'
    END AS value_tier,
    CASE
        WHEN total_orders >= 10 THEN 'Frequent Buyer'
        WHEN total_orders BETWEEN 5 AND 9 THEN 'Regular Buyer'
        WHEN total_orders BETWEEN 2 AND 4 THEN 'Occasional Buyer'
        ELSE 'One-Time Buyer'
    END AS purchase_frequency_segment,
    first_order_date,
    last_order_date,
    recency_months,
    recency_days,
    lifespan_months,
    total_orders,
    total_products,
    total_quantity,
    total_sales AS customer_lifetime_value,
    avg_transaction_value,
    ROUND(total_sales / NULLIF(total_orders, 0), 2) AS avg_order_value,
    ROUND(total_sales / NULLIF(lifespan_months, 0), 2) AS avg_monthly_spend,
    ROUND(total_orders / NULLIF(lifespan_months, 0), 2) AS avg_orders_per_month,
    ROUND(total_quantity / NULLIF(total_orders, 0), 2) AS avg_items_per_order,
    ROUND(total_products / NULLIF(total_orders, 0), 2) AS product_diversity_score,
    highest_price_paid,
    lowest_price_paid,
    ROUND(avg_price_paid, 2) AS avg_price_paid,
    CASE
        WHEN total_sales >= 5000 AND recency_months <= 3 AND total_orders >= 5 THEN 'Excellent'
        WHEN total_sales >= 2000 AND recency_months <= 6 THEN 'Good'
        WHEN total_sales >= 1000 OR recency_months <= 6 THEN 'Fair'
        ELSE 'Poor'
    END AS customer_health_score,
    DENSE_RANK() OVER(ORDER BY total_sales DESC) AS revenue_rank,
    DENSE_RANK() OVER(ORDER BY total_orders DESC) AS order_frequency_rank,
    DENSE_RANK() OVER(PARTITION BY country ORDER BY total_sales DESC) AS country_revenue_rank,
    NTILE(10) OVER(ORDER BY total_sales DESC) AS revenue_decile,
    NTILE(4) OVER(ORDER BY total_sales DESC) AS revenue_quartile
FROM customer_metrics
)
SELECT * FROM customer_segmented;