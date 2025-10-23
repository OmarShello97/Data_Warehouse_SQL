/*
============================================================
CUSTOMER ANALYTICS REPORT
============================================================

Purpose:
    Comprehensive customer-level analytics view that consolidates
    behavioral patterns, purchase history, and segmentation
    for customer relationship management and marketing insights.

Key Metrics:
    - Customer Value: Lifetime value, average order value, purchase frequency
    - Engagement: Recency, lifespan, order frequency
    - Product Affinity: Unique products purchased, basket diversity
    - Segmentation: Lifecycle stage, age demographics, value tier

Business Use Cases:
    - Customer retention strategies
    - Targeted marketing campaigns
    - Loyalty program development
    - Churn prediction and prevention
    - Customer lifetime value optimization
    - Personalization strategies

============================================================
*/
USE DataWarehouseAnalytics;
GO

CREATE OR ALTER VIEW gold.report_customers AS 
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
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age,
        c.birthdate
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_customers c ON s.customer_key = c.customer_key
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
        -- Purchase metrics
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        AVG(sales_amount) AS avg_transaction_value,
        -- Temporal metrics
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months,
        DATEDIFF(MONTH, MAX(order_date), GETDATE()) AS recency_months,
        DATEDIFF(DAY, MAX(order_date), GETDATE()) AS recency_days,
        -- Additional insights
        MAX(price) AS highest_price_paid,
        MIN(price) AS lowest_price_paid,
        AVG(price) AS avg_price_paid
    FROM customer_transactions
    GROUP BY 
        customer_key,
        customer_number,
        first_name,
        last_name,
        full_name,
        country,
        gender,
        age,
        birthdate
),
customer_segmented AS (
SELECT
    -- Customer identifiers
    customer_key,
    customer_number,
    first_name,
    last_name,
    full_name,
    
    -- Demographics
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
    
    -- Lifecycle segmentation
    CASE 
        WHEN lifespan_months >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan_months >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    
    -- RFM-inspired recency status
    CASE
        WHEN recency_months <= 3 THEN 'Active'
        WHEN recency_months BETWEEN 4 AND 6 THEN 'At Risk'
        WHEN recency_months BETWEEN 7 AND 12 THEN 'Dormant'
        ELSE 'Churned'
    END AS engagement_status,
    
    -- Value tier segmentation
    CASE
        WHEN total_sales >= 10000 THEN 'High Value'
        WHEN total_sales BETWEEN 5000 AND 9999 THEN 'Medium Value'
        WHEN total_sales BETWEEN 1000 AND 4999 THEN 'Low Value'
        ELSE 'Entry Level'
    END AS value_tier,
    
    -- Purchase frequency segmentation
    CASE
        WHEN total_orders >= 10 THEN 'Frequent Buyer'
        WHEN total_orders BETWEEN 5 AND 9 THEN 'Regular Buyer'
        WHEN total_orders BETWEEN 2 AND 4 THEN 'Occasional Buyer'
        ELSE 'One-Time Buyer'
    END AS purchase_frequency_segment,
    
    -- Temporal information
    first_order_date,
    last_order_date,
    recency_months,
    recency_days,
    lifespan_months,
    
    -- Volume metrics
    total_orders,
    total_products,
    total_quantity,
    
    -- Revenue metrics
    total_sales AS customer_lifetime_value,
    avg_transaction_value,
    
    -- Calculated KPIs
    ROUND(CAST(total_sales AS FLOAT) / NULLIF(total_orders, 0), 2) AS avg_order_value,
    ROUND(CAST(total_sales AS FLOAT) / NULLIF(lifespan_months, 0), 2) AS avg_monthly_spend,
    ROUND(CAST(total_orders AS FLOAT) / NULLIF(lifespan_months, 0), 2) AS avg_orders_per_month,
    ROUND(CAST(total_quantity AS FLOAT) / NULLIF(total_orders, 0), 2) AS avg_items_per_order,
    ROUND(CAST(total_products AS FLOAT) / NULLIF(total_orders, 0), 2) AS product_diversity_score,
    
    -- Pricing insights
    highest_price_paid,
    lowest_price_paid,
    ROUND(avg_price_paid, 2) AS avg_price_paid,
    
    -- Customer health score
    CASE
        WHEN total_sales >= 5000 AND recency_months <= 3 AND total_orders >= 5 THEN 'Excellent'
        WHEN total_sales >= 2000 AND recency_months <= 6 THEN 'Good'
        WHEN total_sales >= 1000 OR recency_months <= 6 THEN 'Fair'
        ELSE 'Poor'
    END AS customer_health_score,
    
    -- Ranking metrics
    DENSE_RANK() OVER(ORDER BY total_sales DESC) AS revenue_rank,
    DENSE_RANK() OVER(ORDER BY total_orders DESC) AS order_frequency_rank,
    DENSE_RANK() OVER(PARTITION BY country ORDER BY total_sales DESC) AS country_revenue_rank,
    
    -- Percentile analysis
    NTILE(10) OVER(ORDER BY total_sales DESC) AS revenue_decile,
    NTILE(4) OVER(ORDER BY total_sales DESC) AS revenue_quartile

FROM customer_metrics
)
SELECT
    -- Customer identifiers
    customer_key,
    customer_number,
    first_name,
    last_name,
    full_name,
    
    -- Demographics
    age,
    age_group,
    gender,
    country,
    birthdate,
    
    -- Segmentation
    customer_segment,
    engagement_status,
    value_tier,
    purchase_frequency_segment,
    
    -- Temporal information
    first_order_date,
    last_order_date,
    recency_months,
    recency_days,
    lifespan_months,
    
    -- Volume metrics
    total_orders,
    total_products,
    total_quantity,
    
    -- Revenue metrics
    customer_lifetime_value,
    avg_transaction_value,
    
    -- Calculated KPIs
    avg_order_value,
    avg_monthly_spend,
    avg_orders_per_month,
    avg_items_per_order,
    product_diversity_score,
    
    -- Pricing insights
    highest_price_paid,
    lowest_price_paid,
    avg_price_paid,
    
    -- Customer health score
    customer_health_score,
    
    -- Ranking metrics
    revenue_rank,
    order_frequency_rank,
    country_revenue_rank,
    
    -- Percentile analysis
    revenue_decile,
    revenue_quartile

FROM customer_segmented;
