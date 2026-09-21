"""
EDA for the Synthetic E-commerce Growth Analytics Portfolio
Requires: pandas, numpy, matplotlib, seaborn, duckdb
Run from the project root.
"""

from pathlib import Path
import duckdb
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "ecommerce.duckdb"
FIG = ROOT / "reports" / "figures"
FIG.mkdir(parents=True, exist_ok=True)

con = duckdb.connect(str(DB))

monthly = con.sql("SELECT * FROM monthly_kpis ORDER BY order_month").df()
products = con.sql("SELECT * FROM product_performance ORDER BY revenue DESC").df()
customers = con.sql("SELECT * FROM customer_360").df()
cohorts = con.sql("SELECT * FROM customer_cohorts").df()
marketing = con.sql("SELECT * FROM marketing_performance").df()

sns.set_theme(style="whitegrid")

# 1. Revenue trend
plt.figure(figsize=(11,6))
sns.lineplot(data=monthly, x="order_month", y="revenue", marker="o")
plt.title("Monthly Revenue")
plt.xlabel("Month")
plt.ylabel("Revenue (£)")
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig(FIG/"01_monthly_revenue.png", dpi=160)
plt.close()

# 2. Orders and AOV
fig, ax1 = plt.subplots(figsize=(11,6))
sns.barplot(data=monthly, x="order_month", y="orders", ax=ax1)
ax1.set_title("Monthly Orders and Average Order Value")
ax1.set_xlabel("")
ax1.set_ylabel("Orders")
ax1.tick_params(axis="x", rotation=45)
ax2 = ax1.twinx()
sns.lineplot(data=monthly, x="order_month", y="aov", marker="o", ax=ax2)
ax2.set_ylabel("AOV (£)")
plt.tight_layout()
plt.savefig(FIG/"02_orders_aov.png", dpi=160)
plt.close()

# 3. Category revenue
cat = con.sql("""
SELECT p.category,
       ROUND(SUM(i.line_revenue),2) AS revenue,
       ROUND(SUM(i.line_gross_profit),2) AS gross_profit
FROM order_items_clean i
JOIN products_clean p USING(product_id)
JOIN orders_clean o USING(order_id)
WHERE o.status='Completed'
GROUP BY p.category
ORDER BY revenue DESC
""").df()
plt.figure(figsize=(10,6))
sns.barplot(data=cat, x="revenue", y="category")
plt.title("Revenue by Product Category")
plt.xlabel("Revenue (£)")
plt.ylabel("")
plt.tight_layout()
plt.savefig(FIG/"03_category_revenue.png", dpi=160)
plt.close()

# 4. Top products
top10 = products.head(10).sort_values("revenue")
plt.figure(figsize=(10,6))
sns.barplot(data=top10, x="revenue", y="product_name")
plt.title("Top 10 Products by Revenue")
plt.xlabel("Revenue (£)")
plt.ylabel("")
plt.tight_layout()
plt.savefig(FIG/"04_top_products.png", dpi=160)
plt.close()

# 5. Customer segments
seg = customers.groupby("customer_segment", as_index=False).agg(
    customers=("customer_id","count"),
    revenue=("total_revenue","sum"),
    avg_order_value=("avg_order_value","mean")
)
plt.figure(figsize=(9,6))
sns.barplot(data=seg, x="customer_segment", y="revenue")
plt.title("Revenue by Customer Segment")
plt.xlabel("")
plt.ylabel("Revenue (£)")
plt.xticks(rotation=20)
plt.tight_layout()
plt.savefig(FIG/"05_customer_segments.png", dpi=160)
plt.close()

# 6. Acquisition channel
channel = con.sql("""
SELECT c.acquisition_channel,
       COUNT(DISTINCT CASE WHEN o.status='Completed' THEN o.order_id END) AS orders,
       ROUND(SUM(CASE WHEN o.status='Completed' THEN i.line_revenue ELSE 0 END),2) AS revenue
FROM customers_clean c
JOIN orders_clean o USING(customer_id)
JOIN order_items_clean i USING(order_id)
GROUP BY c.acquisition_channel
ORDER BY revenue DESC
""").df()
plt.figure(figsize=(10,6))
sns.barplot(data=channel, x="revenue", y="acquisition_channel")
plt.title("Revenue by Customer Acquisition Channel")
plt.xlabel("Revenue (£)")
plt.ylabel("")
plt.tight_layout()
plt.savefig(FIG/"06_acquisition_channel.png", dpi=160)
plt.close()

# 7. Discount vs AOV
order_level = con.sql("""
SELECT order_id, AVG(discount_pct) AS discount_pct, SUM(line_revenue) AS revenue
FROM order_items_clean
GROUP BY order_id
""").df()
plt.figure(figsize=(9,6))
sns.scatterplot(data=order_level.sample(min(10000,len(order_level)), random_state=42),
                x="discount_pct", y="revenue", alpha=.25)
plt.title("Discount Level vs Order Revenue")
plt.xlabel("Average discount")
plt.ylabel("Order revenue (£)")
plt.tight_layout()
plt.savefig(FIG/"07_discount_vs_revenue.png", dpi=160)
plt.close()

# 8. Cohort heatmap
pivot = cohorts.pivot_table(index="cohort_month", columns="months_since_first_purchase",
                            values="active_customers", aggfunc="sum")
cohort_size = pivot[0]
retention = pivot.divide(cohort_size, axis=0) * 100
plt.figure(figsize=(13,8))
sns.heatmap(retention.iloc[:, :10], annot=True, fmt=".0f", cmap="Blues", cbar_kws={"label":"Retention %"})
plt.title("Customer Cohort Retention")
plt.xlabel("Months Since First Purchase")
plt.ylabel("Cohort Month")
plt.tight_layout()
plt.savefig(FIG/"08_cohort_retention.png", dpi=160)
plt.close()

# 9. Marketing spend
mkt = marketing.groupby("month", as_index=False)["spend"].sum()
plt.figure(figsize=(11,6))
sns.lineplot(data=mkt, x="month", y="spend", marker="o")
plt.title("Monthly Marketing Spend")
plt.xlabel("Month")
plt.ylabel("Spend (£)")
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig(FIG/"09_marketing_spend.png", dpi=160)
plt.close()

print("EDA complete. Figures saved to reports/figures/")
