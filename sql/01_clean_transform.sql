-- E-commerce Growth & Customer Analytics
-- Dialect: DuckDB
-- Run from the project root after installing DuckDB.
-- This script cleans raw CSVs and creates analysis-ready tables.

CREATE OR REPLACE TABLE customers_clean AS
SELECT
    CAST(customer_id AS INTEGER) AS customer_id,
    CAST(signup_date AS DATE) AS signup_date,
    COALESCE(CAST(age AS INTEGER), 35) AS age,
    INITCAP(TRIM(COALESCE(region, 'Unknown'))) AS region,
    INITCAP(TRIM(COALESCE(acquisition_channel, 'Unknown'))) AS acquisition_channel,
    INITCAP(TRIM(COALESCE(loyalty_tier, 'Standard'))) AS loyalty_tier
FROM read_csv_auto('data/raw/customers.csv')
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY signup_date) = 1;

CREATE OR REPLACE TABLE products_clean AS
SELECT
    CAST(product_id AS INTEGER) AS product_id,
    TRIM(product_name) AS product_name,
    INITCAP(TRIM(category)) AS category,
    INITCAP(TRIM(brand)) AS brand,
    ROUND(CAST(list_price AS DOUBLE), 2) AS list_price,
    ROUND(CAST(unit_cost AS DOUBLE), 2) AS unit_cost
FROM read_csv_auto('data/raw/products.csv')
QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) = 1;

CREATE OR REPLACE TABLE orders_clean AS
SELECT
    CAST(order_id AS BIGINT) AS order_id,
    CAST(customer_id AS INTEGER) AS customer_id,
    CAST(order_datetime AS TIMESTAMP) AS order_datetime,
    INITCAP(TRIM(status)) AS status,
    INITCAP(TRIM(payment_method)) AS payment_method,
    INITCAP(TRIM(device)) AS device
FROM read_csv_auto('data/raw/orders.csv')
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_datetime) = 1;

CREATE OR REPLACE TABLE order_items_clean AS
SELECT
    CAST(order_id AS BIGINT) AS order_id,
    CAST(product_id AS INTEGER) AS product_id,
    GREATEST(CAST(quantity AS INTEGER), 1) AS quantity,
    ROUND(CAST(unit_price AS DOUBLE), 2) AS unit_price,
    ROUND(CAST(unit_cost AS DOUBLE), 2) AS unit_cost,
    COALESCE(CAST(discount_pct AS DOUBLE), 0) AS discount_pct,
    ROUND(GREATEST(CAST(quantity AS INTEGER), 1) * CAST(unit_price AS DOUBLE), 2) AS line_revenue,
    ROUND(GREATEST(CAST(quantity AS INTEGER), 1) * (CAST(unit_price AS DOUBLE) - CAST(unit_cost AS DOUBLE)), 2) AS line_gross_profit
FROM read_csv_auto('data/raw/order_items.csv')
WHERE order_id IS NOT NULL
  AND product_id IS NOT NULL;

CREATE OR REPLACE TABLE marketing_clean AS
SELECT
    CAST(month AS DATE) AS month,
    INITCAP(TRIM(channel)) AS channel,
    CAST(spend AS DOUBLE) AS spend,
    CAST(impressions AS BIGINT) AS impressions,
    CAST(clicks AS BIGINT) AS clicks
FROM read_csv_auto('data/raw/marketing_spend.csv');

-- Core order-level fact table
CREATE OR REPLACE TABLE fact_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_datetime,
    DATE_TRUNC('month', o.order_datetime)::DATE AS order_month,
    o.status,
    o.payment_method,
    o.device,
    c.region,
    c.acquisition_channel,
    c.loyalty_tier,
    SUM(i.line_revenue) AS revenue,
    SUM(i.line_gross_profit) AS gross_profit,
    SUM(i.quantity) AS units,
    COUNT(DISTINCT i.product_id) AS unique_products,
    AVG(i.discount_pct) AS avg_discount_pct
FROM orders_clean o
JOIN customers_clean c USING (customer_id)
JOIN order_items_clean i USING (order_id)
WHERE o.status IN ('Completed', 'Returned')
GROUP BY ALL;

-- Customer-level KPIs and segmentation
CREATE OR REPLACE TABLE customer_360 AS
WITH base AS (
    SELECT
        c.*,
        MIN(f.order_datetime)::DATE AS first_order_date,
        MAX(f.order_datetime)::DATE AS last_order_date,
        COUNT(DISTINCT CASE WHEN f.status='Completed' THEN f.order_id END) AS completed_orders,
        ROUND(SUM(CASE WHEN f.status='Completed' THEN f.revenue ELSE 0 END),2) AS total_revenue,
        ROUND(SUM(CASE WHEN f.status='Completed' THEN f.gross_profit ELSE 0 END),2) AS total_gross_profit,
        ROUND(AVG(CASE WHEN f.status='Completed' THEN f.revenue END),2) AS avg_order_value,
        COUNT(DISTINCT CASE WHEN f.status='Returned' THEN f.order_id END) AS returned_orders
    FROM customers_clean c
    LEFT JOIN fact_orders f USING (customer_id)
    GROUP BY ALL
)
SELECT
    *,
    CASE
        WHEN completed_orders = 0 THEN 'No Purchase'
        WHEN total_revenue >= 500 THEN 'High Value'
        WHEN completed_orders >= 3 THEN 'Repeat'
        ELSE 'One-Time'
    END AS customer_segment,
    ROUND(100.0 * returned_orders / NULLIF(completed_orders + returned_orders,0),2) AS return_rate_pct
FROM base;

-- Monthly performance
CREATE OR REPLACE TABLE monthly_kpis AS
SELECT
    order_month,
    COUNT(DISTINCT CASE WHEN status='Completed' THEN order_id END) AS orders,
    COUNT(DISTINCT CASE WHEN status='Completed' THEN customer_id END) AS purchasing_customers,
    ROUND(SUM(CASE WHEN status='Completed' THEN revenue ELSE 0 END),2) AS revenue,
    ROUND(SUM(CASE WHEN status='Completed' THEN gross_profit ELSE 0 END),2) AS gross_profit,
    SUM(CASE WHEN status='Completed' THEN units ELSE 0 END) AS units,
    ROUND(
        SUM(CASE WHEN status='Completed' THEN revenue ELSE 0 END) /
        NULLIF(COUNT(DISTINCT CASE WHEN status='Completed' THEN order_id END),0), 2
    ) AS aov,
    ROUND(
        100.0 * SUM(CASE WHEN status='Returned' THEN revenue ELSE 0 END) /
        NULLIF(SUM(revenue),0), 2
    ) AS return_revenue_rate_pct
FROM fact_orders
GROUP BY order_month
ORDER BY order_month;

-- Product performance
CREATE OR REPLACE TABLE product_performance AS
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    COUNT(DISTINCT f.order_id) AS orders,
    SUM(i.quantity) AS units_sold,
    ROUND(SUM(CASE WHEN f.status='Completed' THEN i.line_revenue ELSE 0 END),2) AS revenue,
    ROUND(SUM(CASE WHEN f.status='Completed' THEN i.line_gross_profit ELSE 0 END),2) AS gross_profit,
    ROUND(AVG(i.discount_pct),3) AS avg_discount_pct
FROM products_clean p
LEFT JOIN order_items_clean i USING (product_id)
LEFT JOIN fact_orders f USING (order_id)
GROUP BY ALL;

-- Cohort retention: first purchase month vs subsequent purchasing months
CREATE OR REPLACE TABLE customer_cohorts AS
WITH first_purchase AS (
    SELECT customer_id, DATE_TRUNC('month', MIN(order_datetime))::DATE AS cohort_month
    FROM fact_orders
    WHERE status='Completed'
    GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT
        f.customer_id,
        fp.cohort_month,
        DATE_TRUNC('month', f.order_datetime)::DATE AS activity_month
    FROM fact_orders f
    JOIN first_purchase fp USING (customer_id)
    WHERE f.status='Completed'
)
SELECT
    cohort_month,
    activity_month,
    DATE_DIFF('month', cohort_month, activity_month) AS months_since_first_purchase,
    COUNT(DISTINCT customer_id) AS active_customers
FROM activity
GROUP BY ALL
ORDER BY cohort_month, months_since_first_purchase;

-- Marketing efficiency
CREATE OR REPLACE TABLE marketing_performance AS
SELECT
    m.month,
    m.channel,
    m.spend,
    m.impressions,
    m.clicks,
    ROUND(m.spend / NULLIF(m.clicks,0),2) AS cost_per_click
FROM marketing_clean m
ORDER BY m.month, m.channel;
