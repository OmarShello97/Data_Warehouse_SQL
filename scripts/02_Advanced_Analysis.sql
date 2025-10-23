-- ============================================================
-- ADVANCED BUSINESS ANALYSIS
-- ============================================================
-- Purpose: In-depth analysis of trends, performance, contribution,
--          and segmentation patterns
-- ============================================================
USE DataWarehouseAnalytics;
GO

-- ============================================================
-- Section 1: Temporal Trend Analysis
-- ============================================================

-- Monthly sales trends with customer activity
SELECT
    FORMAT(DATETRUNC(MONTH, order_date), 'yyyy-MM') AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    ROUND(AVG(price), 2) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date);

-- Yearly sales trends with customer activity
SELECT
    YEAR(order_date) AS order_year,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(AVG(price), 2) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- Seasonality analysis by month across all years
SELECT
    MONTH(order_date) AS month_number,
    DATENAME(MONTH, order_date) AS month_name,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date), DATENAME(MONTH, order_date)
ORDER BY month_number;

-- Month-over-month comparison with year-to-date aggregations
WITH monthly_sales AS (
    SELECT
        DATETRUNC(MONTH, order_date) AS order_date,
        SUM(sales_amount) AS monthly_total_sales,
        COUNT(DISTINCT customer_key) AS monthly_total_customers
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
)
SELECT
    FORMAT(order_date, 'yyyy-MM') AS order_month,
    monthly_total_sales,
    LAG(monthly_total_sales, 1) OVER (ORDER BY order_date) AS previous_month_sales,
    monthly_total_sales - LAG(monthly_total_sales, 1) OVER (ORDER BY order_date) AS month_over_month_diff,
    ROUND(
        (monthly_total_sales - LAG(monthly_total_sales, 1) OVER (ORDER BY order_date)) / 
        NULLIF(LAG(monthly_total_sales, 1) OVER (ORDER BY order_date), 0) * 100, 
        2
    ) AS month_over_month_growth_pct,
    SUM(monthly_total_sales) OVER (PARTITION BY YEAR(order_date) ORDER BY order_date) AS ytd_sales,
    monthly_total_customers,
    SUM(monthly_total_customers) OVER (PARTITION BY YEAR(order_date)) AS yearly_total_customers
FROM monthly_sales
ORDER BY order_date;

-- ============================================================
-- Section 2: Running Totals and Moving Averages
-- ============================================================

-- Monthly running totals and rolling 3-month averages
WITH monthly_metrics AS (
    SELECT
        DATETRUNC(MONTH, order_date) AS order_month,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
)
SELECT
    FORMAT(order_month, 'yyyy-MM') AS order_month,
    total_sales,
    SUM(total_sales) OVER(ORDER BY order_month) AS running_total_sales,
    AVG(total_sales) OVER(ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_3_month_avg_sales,
    SUM(total_sales) OVER(ORDER BY order_month ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS rolling_3_month_total,
    ROUND(avg_price, 2) AS avg_price,
    ROUND(AVG(avg_price) OVER(ORDER BY order_month), 2) AS cumulative_avg_price
FROM monthly_metrics
ORDER BY order_month;

-- Yearly running totals and moving averages
SELECT
    order_year,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_year) AS running_total_sales,
    AVG(avg_price) OVER (ORDER BY order_year) AS cumulative_avg_price
FROM (
    SELECT 
        YEAR(order_date) AS order_year,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date)
) yearly_data
ORDER BY order_year;

-- ============================================================
-- Section 3: Year-Over-Year Performance Analysis
-- ============================================================

-- Product year-over-year performance comparison
SELECT
    YEAR(s.order_date) AS order_year,
    p.product_name,
    p.category,
    SUM(s.sales_amount) AS current_year_sales,
    LAG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name ORDER BY YEAR(s.order_date)) AS previous_year_sales,
    SUM(s.sales_amount) - LAG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name ORDER BY YEAR(s.order_date)) AS yoy_sales_diff,
    ROUND(
        (SUM(s.sales_amount) - LAG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name ORDER BY YEAR(s.order_date))) / 
        NULLIF(LAG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name ORDER BY YEAR(s.order_date)), 0) * 100,
        2
    ) AS yoy_growth_pct,
    CASE
        WHEN SUM(s.sales_amount) - LAG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name ORDER BY YEAR(s.order_date)) > 0 THEN 'Growth'
        WHEN SUM(s.sales_amount) - LAG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name ORDER BY YEAR(s.order_date)) < 0 THEN 'Decline'
        ELSE 'No Change'
    END AS yoy_trend,
    AVG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name) AS product_avg_sales,
    SUM(s.sales_amount) - AVG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name) AS diff_from_avg,
    CASE
        WHEN SUM(s.sales_amount) - AVG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name) > 0 THEN 'Above Average'
        WHEN SUM(s.sales_amount) - AVG(SUM(s.sales_amount)) OVER(PARTITION BY p.product_name) < 0 THEN 'Below Average'
        ELSE 'At Average'
    END AS performance_vs_avg
FROM gold.fact_sales s
JOIN gold.dim_products p ON s.product_key = p.product_key
WHERE YEAR(s.order_date) IS NOT NULL
GROUP BY p.product_name, p.category, YEAR(s.order_date)
ORDER BY p.product_name, order_year;

-- ============================================================
-- Section 4: Contribution Analysis (Part-to-Whole)
-- ============================================================

-- Category contribution to total sales
WITH category_sales AS (
    SELECT
        p.category,
        SUM(s.sales_amount) AS category_sales,
        COUNT(DISTINCT s.order_number) AS total_orders,
        SUM(s.quantity) AS total_quantity
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_products p ON p.product_key = s.product_key
    GROUP BY p.category
)
SELECT
    category,
    category_sales,
    total_orders,
    total_quantity,
    SUM(category_sales) OVER() AS total_sales,
    ROUND(CAST(category_sales AS FLOAT) / CAST(SUM(category_sales) OVER() AS FLOAT) * 100, 2) AS sales_percentage,
    DENSE_RANK() OVER(ORDER BY category_sales DESC) AS revenue_rank
FROM category_sales
ORDER BY category_sales DESC;

-- Subcategory contribution to total sales
WITH subcategory_sales AS (
    SELECT
        p.category,
        p.subcategory,
        SUM(s.sales_amount) AS subcategory_sales,
        COUNT(DISTINCT s.order_number) AS total_orders
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_products p ON p.product_key = s.product_key
    GROUP BY p.category, p.subcategory
)
SELECT
    category,
    subcategory,
    subcategory_sales,
    total_orders,
    SUM(subcategory_sales) OVER() AS total_sales,
    ROUND(CAST(subcategory_sales AS FLOAT) / CAST(SUM(subcategory_sales) OVER() AS FLOAT) * 100, 2) AS sales_percentage,
    ROUND(CAST(subcategory_sales AS FLOAT) / SUM(subcategory_sales) OVER(PARTITION BY category) * 100, 2) AS category_percentage
FROM subcategory_sales
ORDER BY subcategory_sales DESC;

-- Product contribution to total sales
WITH product_sales AS (
    SELECT
        p.product_name,
        p.category,
        p.subcategory,
        SUM(f.sales_amount) AS total_sales,
        SUM(f.quantity) AS total_quantity
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
    GROUP BY p.product_name, p.category, p.subcategory
)
SELECT
    product_name,
    category,
    subcategory,
    total_sales,
    total_quantity,
    SUM(total_sales) OVER() AS overall_total_sales,
    ROUND(CAST(total_sales AS FLOAT) / CAST(SUM(total_sales) OVER() AS FLOAT) * 100, 2) AS sales_percentage,
    DENSE_RANK() OVER(ORDER BY total_sales DESC) AS revenue_rank
FROM product_sales
ORDER BY total_sales DESC;

-- ============================================================
-- Section 5: Customer Segmentation Analysis
-- ============================================================

-- Customer age group segmentation
WITH customer_age_groups AS (
    SELECT
        f.customer_key,
        CASE
            WHEN DATEDIFF(YEAR, c.birthdate, GETDATE()) < 20 THEN 'Under 20'
            WHEN DATEDIFF(YEAR, c.birthdate, GETDATE()) BETWEEN 20 AND 29 THEN '20-29'
            WHEN DATEDIFF(YEAR, c.birthdate, GETDATE()) BETWEEN 30 AND 39 THEN '30-39'
            WHEN DATEDIFF(YEAR, c.birthdate, GETDATE()) BETWEEN 40 AND 49 THEN '40-49'
            ELSE '50+'
        END AS age_group,
        SUM(f.sales_amount) AS total_sales,
        COUNT(DISTINCT f.order_number) AS total_orders
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    GROUP BY f.customer_key, DATEDIFF(YEAR, c.birthdate, GETDATE())
)
SELECT
    age_group,
    COUNT(customer_key) AS total_customers,
    SUM(total_sales) AS total_sales,
    SUM(total_orders) AS total_orders,
    ROUND(AVG(total_sales), 2) AS avg_sales_per_customer,
    ROUND(CAST(SUM(total_sales) AS FLOAT) / SUM(SUM(total_sales)) OVER() * 100, 2) AS sales_percentage
FROM customer_age_groups
GROUP BY age_group
ORDER BY total_sales DESC;

-- Product cost range segmentation
WITH product_cost_segments AS (
    SELECT
        product_key,
        category,
        CASE 
            WHEN cost < 100 THEN 'Below $100'
            WHEN cost BETWEEN 100 AND 499 THEN '$100-$499'
            WHEN cost BETWEEN 500 AND 1000 THEN '$500-$1000'
            ELSE 'Above $1000'
        END AS cost_range
    FROM gold.dim_products
)
SELECT
    cost_range,
    COUNT(product_key) AS total_products,
    ROUND(CAST(COUNT(product_key) AS FLOAT) / SUM(COUNT(product_key)) OVER() * 100, 2) AS product_percentage
FROM product_cost_segments
GROUP BY cost_range
ORDER BY 
    CASE cost_range
        WHEN 'Below $100' THEN 1
        WHEN '$100-$499' THEN 2
        WHEN '$500-$1000' THEN 3
        WHEN 'Above $1000' THEN 4
    END;

-- Product performance segmentation
WITH product_performance AS (
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        SUM(s.sales_amount) AS total_sales,
        CASE 
            WHEN SUM(s.sales_amount) < 200000 THEN 'Low Performance'
            WHEN SUM(s.sales_amount) BETWEEN 200000 AND 749999 THEN 'Mid Range'
            WHEN SUM(s.sales_amount) >= 750000 THEN 'High Performance'
        END AS performance_segment
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_products p ON s.product_key = p.product_key
    GROUP BY p.product_key, p.product_name, p.category
)
SELECT
    performance_segment,
    COUNT(product_key) AS total_products,
    ROUND(AVG(total_sales), 2) AS avg_sales_per_product,
    MIN(total_sales) AS min_sales,
    MAX(total_sales) AS max_sales,
    ROUND(CAST(COUNT(product_key) AS FLOAT) / SUM(COUNT(product_key)) OVER() * 100, 2) AS product_percentage
FROM product_performance
GROUP BY performance_segment
ORDER BY 
    CASE performance_segment
        WHEN 'High Performance' THEN 1
        WHEN 'Mid Range' THEN 2
        WHEN 'Low Performance' THEN 3
    END;

-- Customer lifecycle segmentation
WITH customer_spending AS (
    SELECT
        c.customer_key,
        c.first_name,
        c.last_name,
        SUM(f.sales_amount) AS total_spending,
        COUNT(DISTINCT f.order_number) AS total_orders,
        MIN(f.order_date) AS first_order_date,
        MAX(f.order_date) AS last_order_date,
        DATEDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS lifespan_months
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    GROUP BY c.customer_key, c.first_name, c.last_name
),
customer_segments AS (
    SELECT 
        customer_key,
        first_name,
        last_name,
        total_spending,
        total_orders,
        lifespan_months,
        CASE 
            WHEN lifespan_months >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan_months >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
)
SELECT 
    customer_segment,
    COUNT(customer_key) AS total_customers,
    ROUND(AVG(total_spending), 2) AS avg_spending,
    ROUND(AVG(total_orders), 2) AS avg_orders,
    ROUND(AVG(lifespan_months), 2) AS avg_lifespan_months,
    ROUND(CAST(COUNT(customer_key) AS FLOAT) / SUM(COUNT(customer_key)) OVER() * 100, 2) AS customer_percentage
FROM customer_segments
GROUP BY customer_segment
ORDER BY 
    CASE customer_segment
        WHEN 'VIP' THEN 1
        WHEN 'Regular' THEN 2
        WHEN 'New' THEN 3
    END;