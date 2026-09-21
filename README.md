# E-commerce Growth & Customer Analytics

## Project Overview

This portfolio project analyses a synthetic UK e-commerce retailer selling sportswear, lifestyle, outdoor and wellness products.


> **Important:** All data is synthetic. It does not represent a real company or real customers.

## Business Context

The retailer has grown rapidly but wants to understand **what is driving revenue growth and whether that growth is sustainable**.

The leadership team wants answers to questions such as:

- How is revenue changing throughout the year?
- Which product categories and products generate the most revenue and gross profit?
- Are customers making repeat purchases?
- Which acquisition channels are associated with high-value customers?
- How do discounts relate to order value?
- Which customer cohorts show stronger retention?
- How much revenue is exposed to returns?
- How does marketing spend change over time?

## Dataset

The raw dataset contains approximately:

| Table | Description | Approx. size |
|---|---|---:|
| `customers.csv` | Customer demographics, region, acquisition channel and loyalty tier | 20K+ rows |
| `products.csv` | Product catalogue, category, brand, price and unit cost | 60+ rows |
| `orders.csv` | Order-level transactions and device/payment information | 65K+ rows |
| `order_items.csv` | Individual products within each order | 100K+ rows |
| `marketing_spend.csv` | Monthly marketing spend, impressions and clicks by channel | 72 rows |

The synthetic data covers **January–December 2025** for transactions and includes customer sign-ups spanning 2024–2025.

The generator deliberately includes realistic data-quality problems such as duplicate records, missing values, inconsistent casing, zero quantities and occasional abnormal values. This makes the SQL stage closer to a real analytics workflow rather than a perfectly clean classroom dataset.

## Data Model

The main analytical relationships are:

```text
customers
    |
    | customer_id
    v
orders
    |
    | order_id
    v
order_items
    |
    | product_id
    v
products

marketing_spend
    |
    | month + channel
    v
marketing analysis
```

The SQL pipeline creates:

- `customers_clean`
- `products_clean`
- `orders_clean`
- `order_items_clean`
- `marketing_clean`
- `fact_orders`
- `customer_360`
- `monthly_kpis`
- `product_performance`
- `customer_cohorts`
- `marketing_performance`

## Tools Used

- **SQL / DuckDB** — cleaning, joins, aggregation, CTEs and window functions
- **Python** — exploratory data analysis
- **Pandas** — data manipulation
- **Matplotlib / Seaborn** — visualisation
- **Git / GitHub** — version control and portfolio presentation

## Project Workflow

### 1. Data generation

The raw data was generated programmatically rather than downloaded from an existing dataset.

The generator introduces:

- seasonal demand
- higher November/December purchasing
- customer acquisition differences
- repeat purchasing behaviour
- product/category differences
- discounts
- returns and cancellations
- different payment methods and devices
- marketing-spend variation
- missing and duplicated records

The purpose is to create a dataset that behaves more like operational business data.

### 2. SQL data cleaning

The SQL pipeline first standardises the raw tables.

Examples include:

- removing duplicate customers and orders using `ROW_NUMBER()`
- standardising text with `TRIM()` and `INITCAP()`
- replacing missing demographic values
- preventing invalid quantities from entering revenue calculations
- calculating line revenue and gross profit
- joining customer, order and product information
- creating monthly and customer-level analytical tables

A simplified example:

```sql
SELECT
    order_id,
    product_id,
    GREATEST(quantity, 1) AS quantity,
    ROUND(quantity * unit_price, 2) AS line_revenue
FROM order_items_clean;
```

### 3. Analytical transformations

The project then moves from cleaned operational tables to business-focused datasets.

#### Monthly KPIs

Metrics include:

- completed orders
- purchasing customers
- revenue
- gross profit
- units sold
- average order value
- return revenue rate

#### Customer 360

Each customer is assigned metrics such as:

- first purchase date
- latest purchase date
- completed order count
- total revenue
- gross profit
- average order value
- returned orders
- return rate
- customer segment

The segmentation is deliberately simple and interpretable:

- **No Purchase**
- **One-Time**
- **Repeat**
- **High Value**

### 4. Exploratory Data Analysis

Python is used to investigate the cleaned data visually.

The analysis includes:

1. Monthly revenue trend
2. Monthly orders and average order value
3. Revenue by product category
4. Top products by revenue
5. Revenue by customer segment
6. Revenue by acquisition channel
7. Discount level vs order revenue
8. Customer cohort retention
9. Monthly marketing spend

## Key Analytical Questions

### Revenue growth

A useful starting point is to compare monthly revenue with order volume and AOV rather than looking at revenue alone.

If revenue rises while AOV remains stable, growth is more likely to be volume-driven. If AOV rises faster than order volume, product mix, pricing or discounting may be contributing more heavily.

### Product performance

Revenue alone can hide differences in profitability.

For example, a high-revenue product sold with substantial discounts may contribute less gross profit than a lower-volume product with stronger margins.

This is why the project calculates both:

```text
Revenue
Gross Profit
```

at product and category level.

### Customer retention

The cohort analysis groups customers according to the month of their first completed purchase.

The resulting retention matrix makes it possible to compare how many customers from each acquisition cohort return in subsequent months.

This is particularly useful because a business can increase first-time purchases without necessarily improving long-term customer value.

### Acquisition

Customer acquisition channel is linked to customer-level purchasing behaviour.

This allows the analysis to move beyond:

> "Which channel generated the most customers?"

towards:

> "Which channels are associated with customers who generate more revenue over time?"

A complete commercial analysis would combine this with marketing spend to calculate metrics such as CAC and ROAS.

### Discounting

Discounts are analysed against order revenue to investigate whether larger discounts correspond to larger baskets.

This should not be interpreted as proof that discounts cause higher revenue. The relationship may be affected by promotions, product type, seasonality and customer intent.

## Example SQL Techniques Demonstrated

The project deliberately uses techniques that are useful in junior analyst roles:

```sql
ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY signup_date
)
```

for duplicate handling.

```sql
DATE_TRUNC('month', order_datetime)
```

for time-based aggregation.

```sql
COUNT(DISTINCT customer_id)
```

for customer-level KPIs.

```sql
CASE
    WHEN completed_orders = 0 THEN 'No Purchase'
    WHEN total_revenue >= 500 THEN 'High Value'
    WHEN completed_orders >= 3 THEN 'Repeat'
    ELSE 'One-Time'
END
```

for segmentation.

The project also demonstrates:

- CTEs
- joins
- conditional aggregation
- `NULLIF`
- window functions
- date functions
- grouped transformations
- analytical tables

## Example Business Findings to Investigate

The synthetic dataset intentionally contains patterns that should be discovered through analysis rather than simply assumed.

The analysis should investigate:

- the seasonal uplift around November and December
- differences in revenue contribution across categories
- the relationship between repeat customers and total revenue
- whether high-value customers are concentrated in particular acquisition channels
- how return rates vary over time
- whether discounting is associated with larger baskets
- whether later customer cohorts retain differently from earlier cohorts
- whether marketing spend increases during high-demand periods

The exact figures should be generated from the SQL pipeline and charts rather than hard-coded into the project description.

## Project Structure

```text
ecommerce-analytics-portfolio/
│
├── data/
│   ├── raw/
│   │   ├── customers.csv
│   │   ├── products.csv
│   │   ├── orders.csv
│   │   ├── order_items.csv
│   │   └── marketing_spend.csv
│   │
│   └── processed/
│
├── sql/
│   └── 01_clean_transform.sql
│
├── src/
│   └── eda.py
│
├── reports/
│   └── figures/
│
├── notebooks/
│
├── requirements.txt
├── DATA_GENERATION.md
├── DATASET_SUMMARY.txt
├── data_dictionary.csv
└── README.md
```

## How to Run

### Install dependencies

```bash
pip install duckdb pandas numpy matplotlib seaborn
```

### Create the database

From the project root:

```bash
duckdb ecommerce.duckdb < sql/01_clean_transform.sql
```

### Run the EDA

```bash
python src/eda.py
```

The charts will be saved to:

```text
reports/figures/
```

## Potential Extensions

This project can be extended further by adding:

- a Power BI dashboard
- RFM customer segmentation
- customer lifetime value
- customer acquisition cost
- ROAS
- statistical testing of promotional campaigns
- predictive churn modelling
- demand forecasting
- product recommendation analysis
- an interactive Streamlit dashboard
- automated data-quality tests
- dbt models and documentation

## Author

**Riaz Rahman**

Data Analytics Portfolio Project
