-- ============================================================
-- EXPLORATORY DATA ANALYSIS (EDA)
-- ============================================================
-- Purpose: Comprehensive database exploration covering structure,
--          dimensions, metrics, distributions, and rankings
-- ============================================================
USE DataWarehouseAnalytics;

-- ============================================================
-- Section 1: Database Structure Exploration
-- ============================================================

-- Display table names with column counts
WITH cleaned_table AS (
    SELECT
        SUBSTRING_INDEX(table_name, '_', -1) AS table_name,
        COUNT(*) AS number_of_columns
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'DataWarehouseAnalytics'
    GROUP BY table_name
)
SELECT
    CONCAT(UPPER(LEFT(table_name, 1)), LOWER(SUBSTRING(table_name, 2))) AS table_name,
    number_of_columns
FROM cleaned_table;

-- View complete schema metadata
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = 'DataWarehouseAnalytics';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE table_schema = 'DataWarehouseAnalytics';

-- ============================================================
-- Section 2: Dimension Tables Exploration
-- ============================================================

-- Explore customer geography
SELECT DISTINCT 
    country
FROM gold_dim_customers
ORDER BY country;

-- Review product catalog structure
SELECT 
    product_id,
    product_name,
    category,
    subcategory
FROM gold_dim_products
ORDER BY category, subcategory, product_name;

-- Analyze product hierarchy depth
SELECT
    category,
    COUNT(DISTINCT subcategory) AS number_of_subcategories,
    COUNT(product_key) AS number_of_products
FROM gold_dim_products
GROUP BY category
ORDER BY number_of_subcategories DESC, number_of_products DESC;

-- ============================================================
-- Section 3: Temporal Analysis
-- ============================================================

-- Preview fact table structure
SELECT * FROM gold_fact_sales LIMIT 100;

-- Determine business operational timeframe
SELECT 
    MIN(order_date) AS start_date,
    MAX(order_date) AS end_date,
    TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS duration_in_months,
    TIMESTAMPDIFF(YEAR, MIN(order_date), MAX(order_date)) AS duration_in_years
FROM gold_fact_sales;

-- Analyze customer age demographics
SELECT 
    MIN(TIMESTAMPDIFF(YEAR, birthdate, CURDATE())) AS youngest_age,
    MAX(TIMESTAMPDIFF(YEAR, birthdate, CURDATE())) AS oldest_age,
    AVG(TIMESTAMPDIFF(YEAR, birthdate, CURDATE())) AS average_age,
    MIN(birthdate) AS youngest_birthdate,
    MAX(birthdate) AS oldest_birthdate
FROM gold_dim_customers;

-- ============================================================
-- Section 4: Key Business Metrics
-- ============================================================

WITH kpi_metrics AS (
    SELECT
        SUM(s.sales_amount) AS total_sales,
        SUM(s.quantity) AS total_items_sold,
        AVG(s.price) AS average_price,
        COUNT(DISTINCT s.order_number) AS total_orders,
        COUNT(DISTINCT s.customer_key) AS customers_with_orders,
        (SELECT COUNT(*) FROM gold_dim_products) AS total_products,
        (SELECT COUNT(*) FROM gold_dim_customers) AS total_customers
    FROM gold_fact_sales s
)
SELECT 'Total Sales' AS measure_name, total_sales AS measure_value FROM kpi_metrics
UNION ALL
SELECT 'Items Sold', total_items_sold FROM kpi_metrics
UNION ALL
SELECT 'Average Price', average_price FROM kpi_metrics
UNION ALL
SELECT 'Total Orders', total_orders FROM kpi_metrics
UNION ALL
SELECT 'Total Products', total_products FROM kpi_metrics
UNION ALL
SELECT 'Total Customers', total_customers FROM kpi_metrics
UNION ALL
SELECT 'Customers With Orders', customers_with_orders FROM kpi_metrics
UNION ALL
SELECT 'Customer Engagement Rate (%)', 
       ROUND(customers_with_orders / total_customers * 100, 2) FROM kpi_metrics
UNION ALL
SELECT 'Average Order Value', 
       total_sales / NULLIF(total_orders, 0) FROM kpi_metrics
UNION ALL
SELECT 'Revenue Per Customer', 
       total_sales / NULLIF(customers_with_orders, 0) FROM kpi_metrics;

-- ============================================================
-- Section 5: Distribution Analysis
-- ============================================================

-- Customer distribution by country
WITH country_distribution AS (
    SELECT
        country,
        COUNT(customer_key) AS total_customers
    FROM gold_dim_customers
    GROUP BY country
)
SELECT
    country,
    total_customers,
    ROUND(total_customers / SUM(total_customers) OVER() * 100, 2) AS percentage
FROM country_distribution
ORDER BY total_customers DESC;

-- Customer distribution by gender
WITH gender_distribution AS (
    SELECT
        gender,
        COUNT(customer_key) AS total_customers
    FROM gold_dim_customers
    GROUP BY gender
)
SELECT
    gender,
    total_customers,
    ROUND(total_customers / SUM(total_customers) OVER() * 100, 2) AS percentage
FROM gender_distribution
UNION ALL
SELECT 'Total', SUM(total_customers), 100.00 FROM gender_distribution
ORDER BY total_customers DESC;

-- Product portfolio by category
WITH category_distribution AS (
    SELECT
        category,
        COUNT(product_key) AS total_products
    FROM gold_dim_products
    GROUP BY category
)
SELECT
    category,
    total_products,
    ROUND(total_products / SUM(total_products) OVER() * 100, 2) AS percentage
FROM category_distribution
UNION ALL
SELECT 'Total', SUM(total_products), 100.00 FROM category_distribution
ORDER BY total_products DESC;

-- Average product cost by category
WITH avg_cost_cte AS (
    SELECT
        category,
        AVG(cost) AS avg_cost,
        MIN(cost) AS min_cost,
        MAX(cost) AS max_cost
    FROM gold_dim_products
    GROUP BY category
)
SELECT category, ROUND(avg_cost, 2) AS avg_cost, min_cost, max_cost FROM avg_cost_cte
UNION ALL
SELECT 'Overall Average', ROUND(AVG(avg_cost), 2), MIN(min_cost), MAX(max_cost) FROM avg_cost_cte
ORDER BY avg_cost DESC;

-- Sales revenue by category
WITH category_sales_cte AS (
    SELECT
        p.category, 
        SUM(s.sales_amount) AS total_sales,
        COUNT(DISTINCT s.order_number) AS total_orders
    FROM gold_dim_products p
    RIGHT JOIN gold_fact_sales s ON p.product_key = s.product_key
    GROUP BY p.category
)
SELECT 
    category, 
    total_sales,
    total_orders,
    ROUND(total_sales / SUM(total_sales) OVER() * 100, 2) AS sales_percentage,
    DENSE_RANK() OVER(ORDER BY total_sales DESC) AS revenue_rank
FROM category_sales_cte
UNION ALL
SELECT 'Total', SUM(total_sales), SUM(total_orders), 100.00, NULL FROM category_sales_cte
ORDER BY total_sales DESC;

-- Items sold by country
WITH country_distribution_cte AS (
    SELECT
        c.country,
        SUM(s.quantity) AS total_items_sold,
        SUM(s.sales_amount) AS total_sales
    FROM gold_dim_customers c
    RIGHT JOIN gold_fact_sales s ON c.customer_key = s.customer_key
    GROUP BY c.country
)
SELECT 
    country,
    total_items_sold,
    total_sales,
    ROUND(total_items_sold / SUM(total_items_sold) OVER() * 100, 2) AS items_percentage,
    ROUND(total_sales / SUM(total_sales) OVER() * 100, 2) AS sales_percentage
FROM country_distribution_cte
UNION ALL
SELECT 'Total', SUM(total_items_sold), SUM(total_sales), 100.00, 100.00 FROM country_distribution_cte
ORDER BY total_items_sold DESC;

-- ============================================================
-- Section 6: Customer Value Analysis
-- ============================================================

WITH customer_ltv AS (
    SELECT
        s.customer_key,
        c.first_name,
        c.last_name,
        SUM(s.sales_amount) AS total_sales,
        COUNT(DISTINCT s.order_number) AS total_orders,
        AVG(s.sales_amount) AS avg_transaction_value
    FROM gold_fact_sales s
    LEFT JOIN gold_dim_customers c ON s.customer_key = c.customer_key
    GROUP BY s.customer_key, c.first_name, c.last_name
)
SELECT
    COUNT(customer_key) AS total_customers,
    ROUND(AVG(total_sales), 2) AS avg_customer_ltv,
    ROUND(MIN(total_sales), 2) AS min_customer_ltv,
    ROUND(MAX(total_sales), 2) AS max_customer_ltv,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    ROUND(AVG(avg_transaction_value), 2) AS avg_transaction_value
FROM customer_ltv;

-- Top 10 highest spending customers
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(s.sales_amount) AS total_sales,
    COUNT(DISTINCT s.order_number) AS total_orders,
    ROUND(AVG(s.sales_amount), 2) AS avg_transaction_value
FROM gold_fact_sales s
LEFT JOIN gold_dim_customers c ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_sales DESC
LIMIT 10;

-- Bottom 10 customers by order frequency
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT s.order_number) AS total_orders,
    SUM(s.sales_amount) AS total_sales
FROM gold_fact_sales s
LEFT JOIN gold_dim_customers c ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_orders ASC, total_sales ASC
LIMIT 10;

-- ============================================================
-- Section 7: Product Performance Rankings
-- ============================================================

-- Top 10 products by revenue
SELECT
    p.product_name,
    p.category,
    p.subcategory,
    SUM(s.sales_amount) AS total_sales,
    SUM(s.quantity) AS total_quantity_sold,
    COUNT(DISTINCT s.order_number) AS total_orders
FROM gold_fact_sales s
LEFT JOIN gold_dim_products p ON s.product_key = p.product_key
GROUP BY p.product_name, p.category, p.subcategory
ORDER BY total_sales DESC
LIMIT 10;

-- Top 10 products by revenue with contribution percentage
SELECT * FROM (
    SELECT
        p.product_name,
        p.category,
        SUM(s.sales_amount) AS total_sales,
        ROUND(SUM(s.sales_amount) / SUM(SUM(s.sales_amount)) OVER() * 100, 2) AS sales_percentage,
        DENSE_RANK() OVER(ORDER BY SUM(s.sales_amount) DESC) AS revenue_rank
    FROM gold_fact_sales s
    LEFT JOIN gold_dim_products p ON s.product_key = p.product_key
    GROUP BY p.product_name, p.category
) AS ranked_products
WHERE revenue_rank <= 10;

-- Bottom 10 products by revenue
SELECT
    p.product_name,
    p.category,
    p.subcategory,
    SUM(s.sales_amount) AS total_sales,
    SUM(s.quantity) AS total_quantity_sold
FROM gold_fact_sales s
LEFT JOIN gold_dim_products p ON s.product_key = p.product_key
GROUP BY p.product_name, p.category, p.subcategory
ORDER BY total_sales ASC
LIMIT 10;

-- Top 10 subcategories by revenue
SELECT
    p.subcategory,
    p.category,
    SUM(s.sales_amount) AS total_sales,
    COUNT(DISTINCT p.product_key) AS number_of_products,
    ROUND(SUM(s.sales_amount) / SUM(SUM(s.sales_amount)) OVER() * 100, 2) AS sales_percentage
FROM gold_fact_sales s
LEFT JOIN gold_dim_products p ON s.product_key = p.product_key
GROUP BY p.subcategory, p.category
ORDER BY total_sales DESC
LIMIT 10;

-- Bottom 10 subcategories by revenue
SELECT
    p.subcategory,
    p.category,
    SUM(s.sales_amount) AS total_sales,
    COUNT(DISTINCT p.product_key) AS number_of_products
FROM gold_fact_sales s
LEFT JOIN gold_dim_products p ON s.product_key = p.product_key
GROUP BY p.subcategory, p.category
ORDER BY total_sales ASC
LIMIT 10;