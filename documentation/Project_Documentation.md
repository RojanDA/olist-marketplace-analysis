# Olist Project Documentation

These notes describe the work completed so far on the Olist marketplace project: how the CSVs were inspected and loaded, what was checked and transformed in PostgreSQL, how the Power BI model and measures work, and what the main results mean. The goal is to make the project understandable to another beginner, not just list code.

## 1. Business idea

Olist is a Brazilian online marketplace that connects customers with independent sellers. The business questions in this project focus on order volume, fulfillment speed, delivery reliability, reviews, sales amounts, and returning customers. The dataset covers orders from 2016 through 2018.

The purpose of the analysis is to help someone ask practical questions such as: Are orders being delivered when promised? Does performance differ across locations or product categories? Are review scores different for late orders? How many customers come back to place another order? When a seller or category has very few orders, its percentage can be misleading, so sample size is included beside performance.

## 2. Source CSVs and row counts

The source CSV files are not included in this repository. Eight CSVs were loaded into the PostgreSQL Bronze schema. The geolocation CSV was not loaded or used in this version.

| CSV | Rows loaded | Use in the project |
|---|---:|---|
| `olist_customers_dataset.csv` | 99,441 | Customer record, unique customer identifier, city, state, and ZIP prefix. |
| `olist_orders_dataset.csv` | 99,441 | Order status and purchase, approval, handoff, delivery, and estimated delivery dates. |
| `olist_order_items_dataset.csv` | 112,650 | Items in each order, product and seller IDs, price, freight, and shipping limit. An order can have multiple item rows. |
| `olist_order_payments_dataset.csv` | 103,886 | Payment method, installments, sequence, and amount. An order can have more than one payment record. |
| `olist_order_reviews_dataset.csv` | 99,224 | Review scores, comments, and timestamps. An order may have multiple review rows. |
| `olist_products_dataset.csv` | 32,951 | Product IDs and Portuguese category names. |
| `olist_sellers_dataset.csv` | 3,095 | Seller IDs and seller locations. |
| `product_category_name_translation.csv` | 71 | Portuguese-to-English category name mapping. |
| `olist_geolocation_dataset.csv` | Not loaded | ZIP-prefix coordinates and location information. It was left out of this analysis. |

The Bronze table columns were initially loaded as text. Types were assigned in Silver for fields used as dates, numbers, and sequence values.

## 3. Python and Jupyter work

Python and pandas were used in Jupyter to inspect the CSVs before loading them into PostgreSQL. The inspection checked each file’s row count and column names, and helped confirm which files should be loaded. The geolocation file was skipped because it was not needed for the current questions.

The database connection used SQLAlchemy with the `psycopg` PostgreSQL driver. The local connection was to database `olist_marketplace` on `localhost:5432` as the PostgreSQL user `postgres`. No password is recorded in this document.

The eight loaded files and their row counts were checked against the source CSVs. The counts matched:

- Customers: 99,441
- Orders: 99,441
- Order items: 112,650
- Payments: 103,886
- Reviews: 99,224
- Products: 32,951
- Sellers: 3,095
- Category translations: 71

## 4. PostgreSQL work in pgAdmin

The database uses three schemas:

- **Bronze** stores the imported source data with minimal changes.
- **Silver** holds cleaned and typed tables for analysis.
- **Gold** holds reporting-ready facts, summaries, and views.

### Bronze

Eight CSVs were imported into `bronze`. The raw columns were text, which kept the initial load simple and preserved the source values for checking.

### Data quality checks

The SQL checks in `sql/02_data_check.sql` were used to inspect row counts, missing order milestones, expected keys, duplicate records, and relationships between tables.

Key findings:

- `order_id` was unique in the orders table.
- `(order_id, order_item_id)` was unique in order items.
- `(order_id, payment_sequential)` was unique in payments.
- Product IDs, seller IDs, customer record IDs, and category names in the translation table had no duplicate keys in the checks performed.
- Order items matched to orders, products, and sellers; orders matched to customers. The checks found no unmatched rows for these relationships.
- `review_id` was not a safe unique key: 789 review IDs repeated, accounting for 814 extra rows in the duplicate-key check. Some repeated IDs belonged to different orders, so reviews were retained rather than deduplicated by `review_id` alone.
- `customer_unique_id` repeats across customer records. It is the identifier used for repeat-customer analysis; `customer_id` identifies the order’s customer record.

The orders table had 99,441 rows. Missing milestone timestamps were:

| Order timestamp | Missing rows |
|---|---:|
| Approval time | 160 |
| Carrier handoff time | 1,783 |
| Customer delivery time | 2,965 |

Missing dates depend partly on order status. For example, a canceled order may not have a delivery timestamp. The status check returned:

| Status | Orders | Missing approval | Missing carrier handoff | Missing customer delivery |
|---|---:|---:|---:|---:|
| approved | 2 | 0 | 2 | 2 |
| canceled | 625 | 141 | 550 | 619 |
| created | 5 | 5 | 5 | 5 |
| delivered | 96,478 | 14 | 2 | 8 |
| invoiced | 314 | 0 | 314 | 314 |
| processing | 301 | 0 | 301 | 301 |
| shipped | 1,107 | 0 | 0 | 1,107 |
| unavailable | 609 | 0 | 609 | 609 |

### Silver

The SQL in `sql/03_bronze_to_silver_table.sql` trims whitespace and turns empty strings into SQL `NULL` values. Date fields are cast to timestamps, amounts to numeric values, and sequence/quantity fields to integers where appropriate. Primary keys were added where the checks supported them. The review table has no single-column primary key because `review_id` repeats.

Silver tables include `orders`, `customers`, `products`, `sellers`, `order_items`, `order_payments`, `order_reviews`, and `product_category_translation`.

### Gold

The SQL in `sql/04_silver_to_gold_table.sql` builds reporting tables at the appropriate level of detail:

- `gold.fact_orders`: one row per order, with customer identifiers and state, order status, timestamps, delivery durations, and the on-time result. It has 99,441 rows.
- `gold.fact_order_items`: one row per order item, with product category, seller and customer states, item price and freight, and delivery information. It has 112,650 rows.
- `gold.order_payment_summary`: one row per order with the number of payment records and total payment value. It has 99,440 rows.
- `gold.order_review_summary`: one row per order that has review rows, with review counts and average review score. It has 98,673 rows.
- `gold.v_order_experience`: an order-level view used in Power BI, combining order information with payment and review summaries. It has 99,441 rows.

One delivered order, `bfbd0f9bdef84302105ad712db648a6c`, had no payment record. There were 768 orders without a review summary. Missing values were kept as missing rather than invented.

The item and payment totals were checked between layers. Item price total was **13,591,643.70 BRL**, freight total was **2,251,909.54 BRL**, and payment total was **16,008,872.12 BRL**. These totals come from different data grains: price and freight are item-level amounts, while payment is summarized per order. Payment must not be summed from the item table because an order can have multiple item rows.

### Gold calculations

The order fact table calculates the two delivery durations in hours using the difference between timestamps:

```sql
ROUND(EXTRACT(EPOCH FROM (carrier_handoff_timestamp - purchase_timestamp)) / 3600.0, 2)
ROUND(EXTRACT(EPOCH FROM (customer_delivery_timestamp - purchase_timestamp)) / 3600.0, 2)
```

The actual field names in the query are `order_delivered_carrier_date`, `order_purchase_timestamp`, and `order_delivered_customer_date`. `EXTRACT(EPOCH ...)` returns the difference in seconds; dividing by 3,600 converts it to hours.

The on-time result is `TRUE` only when the order is delivered and both actual and estimated delivery dates exist. It is `TRUE` when the actual customer delivery date is on or before the estimated date, `FALSE` when later, and `NULL` when the order is not eligible for the comparison.

## 5. Power BI model and report

Power BI imports `gold.v_order_experience` and `gold.fact_order_items`. The model has a one-to-many relationship from the order-level view to the item-level table by `order_id`, with filtering from the order view to item rows. This allows the order-date slicer to filter item-level visuals.

The report has four pages:

1. **Order Overview** — orders by status, monthly order volume, total orders card, and purchase-date range slicer.
2. **Delivery Performance** — on-time percentage, average purchase-to-carrier hours, average purchase-to-delivery days, customer-state delivery performance, seller-state delivery performance, product-category delivery performance, and review-score comparison by on-time result.
3. **Sales & Customers** — item price, freight and payment totals, and repeat-customer count.
4. **Sample Size Check** — seller and category order counts alongside on-time percentages, to show when a percentage is based on very few orders.

The intended slicer setup applies the purchase-date range to the overview, delivery, and sales pages. The sample-size page is left unsynced so it can show a full-history baseline. Clicking a seller or category row can cross-filter the other table on the sample-size page; clear the selection to restore the unfiltered values.

### Delivery measure definitions

An **eligible delivered order** is an order with `order_status = "delivered"` and both actual customer-delivery and estimated-delivery dates present. The percentage denominator uses only those eligible orders.

The overall check found:

- Delivered orders: 96,478
- Eligible delivered orders: 96,470
- On-time orders: 88,644
- Late orders: 7,826
- On-time delivery: 91.89%

The eight delivered orders without both required dates are excluded from the on-time percentage. The final Power BI measure uses explicit status and date checks; an earlier version counted a Boolean field incorrectly and returned 100%. The corrected measure returned 91.89%.

### Power BI DAX measures

The following measures were created or used in the report. Each formula is followed by its purpose. Column names are shown with their Power BI table names.

#### Order-level measures (`gold v_order_experience`)

**Total Orders** — counts each order once.

```DAX
Total Orders =
DISTINCTCOUNT('gold v_order_experience'[order_id])
```

**Eligible Delivered Orders** — counts only delivered orders with both dates needed to compare actual and estimated delivery.

```DAX
Eligible Delivered Orders =
CALCULATE(
    DISTINCTCOUNT('gold v_order_experience'[order_id]),
    'gold v_order_experience'[order_status] = "delivered",
    NOT ISBLANK('gold v_order_experience'[order_delivered_customer_date]),
    NOT ISBLANK('gold v_order_experience'[order_estimated_delivery_date])
)
```

**On-time Orders** — counts distinct orders marked on time.

```DAX
On-time Orders =
CALCULATE(
    DISTINCTCOUNT('gold v_order_experience'[order_id]),
    'gold v_order_experience'[delivered_on_time] = TRUE()
)
```

**On-time Delivery %** — on-time eligible orders divided by eligible delivered orders. Formatted as a percentage with two decimal places.

```DAX
On-time Delivery % =
DIVIDE([On-time Orders], [Eligible Delivered Orders])
```

**Payment Value (BRL)** — sums order-level payment values from the order experience view.

```DAX
Payment Value (BRL) =
SUM('gold v_order_experience'[total_payment_value])
```

**Average Order Review Score** — averages the order-level review score summary.

```DAX
Average Order Review Score =
AVERAGE('gold v_order_experience'[average_review_score])
```

**Orders With Review** — counts distinct orders with a review score.

```DAX
Orders With Review =
CALCULATE(
    DISTINCTCOUNT('gold v_order_experience'[order_id]),
    NOT ISBLANK('gold v_order_experience'[average_review_score])
)
```

**Average Purchase-to-Delivery Days** — averages purchase-to-delivery hours for delivered orders, then converts hours to days. Formatted to one decimal place.

```DAX
Average Purchase-to-Delivery Days =
CALCULATE(
    AVERAGE('gold v_order_experience'[purchase_to_delivery_hours]) / 24,
    'gold v_order_experience'[order_status] = "delivered"
)
```

**Average Purchase-to-Carrier Hours** — averages the purchase-to-carrier duration in hours. Formatted to one decimal place.

```DAX
Average Purchase-to-Carrier Hours =
AVERAGE('gold v_order_experience'[purchase_to_carrier_hours])
```

**Repeat Customers** — counts unique customers who have placed more than one distinct order. It uses `customer_unique_id`, not the order-specific customer record ID.

```DAX
Repeat Customers =
COUNTROWS(
    FILTER(
        VALUES('gold v_order_experience'[customer_unique_id]),
        NOT ISBLANK('gold v_order_experience'[customer_unique_id])
            && CALCULATE(
                DISTINCTCOUNT('gold v_order_experience'[order_id])
            ) > 1
    )
)
```

#### Item-level measures (`gold fact_order_items`)

These measures use distinct `order_id` values, even though the source table has one row per item. That avoids counting an order multiple times within the same category or seller group. An order can still appear in more than one category or seller group if it contains items from multiple groups.

**On-time Orders by Item Group** — counts distinct on-time orders in the current category, seller, or other item-table context. The strict equality excludes blank outcomes.

```DAX
On-time Orders by Item Group =
CALCULATE(
    DISTINCTCOUNT('gold fact_order_items'[order_id]),
    'gold fact_order_items'[delivered_on_time] == TRUE()
)
```

**Late Orders by Item Group** — counts distinct late orders in the current item-table context; blank outcomes are excluded.

```DAX
Late Orders by Item Group =
CALCULATE(
    DISTINCTCOUNT('gold fact_order_items'[order_id]),
    'gold fact_order_items'[delivered_on_time] == FALSE()
)
```

**Eligible Delivered Orders by Item Group** — total on-time plus late orders within the current item-table group. Used to display the sample size beside a rate.

```DAX
Eligible Delivered Orders by Item Group =
[On-time Orders by Item Group] + [Late Orders by Item Group]
```

**On-Time Delivery % by Item Group** — share of the eligible orders in a category or seller group that were on time.

```DAX
On-Time Delivery % by Item Group =
DIVIDE(
    [On-time Orders by Item Group],
    [On-time Orders by Item Group] + [Late Orders by Item Group]
)
```

#### Item amount measures (`gold fact_order_items`)

**Total Item Price (BRL)** — sums the item-level price column.

```DAX
Total Item Price (BRL) =
SUM('gold fact_order_items'[price])
```

**Total Freight Value (BRL)** — sums item-level freight values.

```DAX
Total Freight Value (BRL) =
SUM('gold fact_order_items'[freight_value])
```

Payment is deliberately not summed from this item table because the same order payment could repeat on each of its item rows. It is summed from the order-level view instead.

## 6. Findings and lessons

- The dataset contains 99,441 orders, but not every order is delivered or has every delivery timestamp.
- Delivery performance should use the eligible-order definition above. Treating blank delivery outcomes as on time made the first DAX attempt show 100%; explicit eligibility fixed it.
- Some sellers have only one eligible delivered order, and some categories have only a handful. A 100% or 0% rate on a tiny sample is not strong evidence of typical performance. Keep eligible counts beside rates and avoid presenting small groups as reliable best/worst rankings.
- The seller and category sample-size tables can cross-filter each other when a row is selected. A changed total may reflect that selection, rather than a broken measure. Clear the selection to return to the full set.
- A customer can have multiple customer records. Use `customer_unique_id` when counting repeat customers.
- Item price/freight, order payment, review, and order counts have different grains. Summarize many-row tables before joining them to the one-row-per-order table, and use the appropriate fact table for each total.
