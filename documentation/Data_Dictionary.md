# Olist Data Dictionary

This dictionary explains the fields in the source CSVs and how the fields are used in the PostgreSQL and Power BI layers. It is written for readers who are learning the project, so it focuses on what each field represents and how to interpret it.

## How to read this document

- **Source / Bronze** means the original CSV column. Imported Bronze columns were stored as `text` so the source values could be checked before conversion.
- **Silver** means the cleaned PostgreSQL field and its current type, based on `sql/03_bronze_to_silver_table.sql`.
- **Gold** means a reporting-ready fact, summary, or view. Gold types below follow the SQL expressions in `sql/04_silver_to_gold_table.sql` and the Power BI model.
- IDs and ZIP prefixes are kept as text because they identify records or locations; they are not quantities for arithmetic.

Eight CSV files were loaded. The geolocation CSV is present in the project folder but was not loaded. Its columns are documented below for reference.

## Source CSV and Bronze/Silver field dictionary

### Customers — `olist_customers_dataset.csv`

Bronze table: `bronze.olist_customers_dataset`  
Silver table: `silver.customers`  
Source rows: 99,441

| Field | Bronze type | Silver type | Meaning |
|---|---|---|---|
| `customer_id` | text | text, primary key | Customer record ID linked from an order. Use it to join an order to its customer record. |
| `customer_unique_id` | text | text | Identifier for the same customer across customer records. Use this for repeat-customer analysis. |
| `customer_zip_code_prefix` | text | text | Customer ZIP-code prefix. Kept as text to preserve its identifier format. |
| `customer_city` | text | text | Customer city. |
| `customer_state` | text | text | Customer state abbreviation. Used to compare customer delivery outcomes by location. |

### Orders — `olist_orders_dataset.csv`

Bronze table: `bronze.olist_orders_dataset`  
Silver table: `silver.orders`  
Gold table: `gold.fact_orders`  
Source/Silver/Gold order rows: 99,441

| Field | Bronze type | Silver / Gold type | Meaning |
|---|---|---|---|
| `order_id` | text | text, primary key in Silver and Gold | Unique order identifier. |
| `customer_id` | text | text | Customer record associated with the order. Joins to `silver.customers.customer_id`. |
| `order_status` | text | text | Current recorded order status, such as delivered, canceled, or shipped. |
| `order_purchase_timestamp` | text | timestamp | Time the customer placed the order. Used for order trends and elapsed-time calculations. |
| `order_approved_at` | text | timestamp | Time the order was approved. It can be missing. |
| `order_delivered_carrier_date` | text | timestamp | Time the order was handed to the carrier. It can be missing. |
| `order_delivered_customer_date` | text | timestamp | Time the order was delivered to the customer. It can be missing. |
| `order_estimated_delivery_date` | text | timestamp | Estimated delivery date shown for the order. Used as the on-time comparison date. |

### Order items — `olist_order_items_dataset.csv`

Bronze table: `bronze.olist_order_items_dataset`  
Silver table: `silver.order_items`  
Gold table: `gold.fact_order_items`  
Source/Silver/Gold item rows: 112,650

| Field | Bronze type | Silver type | Meaning |
|---|---|---|---|
| `order_id` | text | text | Order that contains the item. An order can appear on multiple item rows. |
| `order_item_id` | text | integer | Item sequence number within an order. Combined with `order_id`, it is the Silver primary key. |
| `product_id` | text | text | Product on the item row. Joins to `silver.products.product_id`. |
| `seller_id` | text | text | Seller responsible for the item. Joins to `silver.sellers.seller_id`. |
| `shipping_limit_date` | text | timestamp | Seller shipping deadline recorded for the item. |
| `price` | text | numeric(12,2) | Item price in Brazilian reais (BRL). Item-level amount. |
| `freight_value` | text | numeric(12,2) | Freight amount associated with the item, in BRL. Item-level amount. |

Gold adds category, seller/customer states, order status, purchase and delivery dates, delivery duration, and on-time result by joining the item to product, seller, and order data. Order-level delivery fields repeat on every item row for that order; do not count them as separate orders without using a distinct order count.

### Payments — `olist_order_payments_dataset.csv`

Bronze table: `bronze.olist_order_payments_dataset`  
Silver table: `silver.order_payments`  
Gold summary: `gold.order_payment_summary`  
Source/Silver rows: 103,886; Gold summary rows: 99,440

| Field | Bronze type | Silver type | Meaning |
|---|---|---|---|
| `order_id` | text | text | Order associated with the payment. An order can have multiple payment rows. |
| `payment_sequential` | text | integer | Sequence of a payment record within an order. Combined with `order_id`, it is the Silver primary key. |
| `payment_type` | text | text | Payment method category. |
| `payment_installments` | text | integer | Number of installments selected for the payment. |
| `payment_value` | text | numeric(12,2) | Amount for this payment record, in BRL. |

`gold.order_payment_summary` groups payment rows by `order_id`:

| Gold field | Type | Meaning |
|---|---|---|
| `order_id` | text, primary key | Order summarized. |
| `payment_record_count` | bigint | Number of payment rows for the order. |
| `total_payment_value` | numeric | Sum of payment amounts for the order, in BRL. |

One delivered order had no payment row, so the payment summary contains one fewer row than the orders table. A missing summary means no payment row was found; it does not mean the payment value is zero.

### Reviews — `olist_order_reviews_dataset.csv`

Bronze table: `bronze.olist_order_reviews_dataset`  
Silver table: `silver.order_reviews`  
Gold summary: `gold.order_review_summary`  
Source/Silver review rows: 99,224; Gold summary rows: 98,673

| Field | Bronze type | Silver type | Meaning |
|---|---|---|---|
| `review_id` | text | text | Review identifier. It repeats in this dataset and is not a safe key by itself. |
| `order_id` | text | text | Order associated with the review. Multiple review rows can exist for an order. |
| `review_score` | text | integer | Customer score, typically on a 1-to-5 scale. |
| `review_comment_title` | text | text | Optional review title. |
| `review_comment_message` | text | text | Optional review message. |
| `review_creation_date` | text | timestamp | Time the review was created. |
| `review_answer_timestamp` | text | timestamp | Time a response to the review was recorded. |

`gold.order_review_summary` groups review rows by order:

| Gold field | Type | Meaning |
|---|---|---|
| `order_id` | text, primary key | Order summarized. |
| `review_row_count` | bigint | Number of review rows associated with the order. |
| `scored_review_count` | bigint | Number of those rows that have a non-null score. |
| `average_review_score` | numeric | Average non-null review score for the order, rounded to two decimals. |

Orders without reviews have no row in this summary. The order experience view keeps those review fields null after the left join.

### Products — `olist_products_dataset.csv`

Bronze table: `bronze.olist_products_dataset`  
Silver table: `silver.products`  
Source rows: 32,951

| Field | Bronze type | Current Silver type/status | Meaning |
|---|---|---|---|
| `product_id` | text | text, primary key | Product identifier. |
| `product_category_name` | text | text | Product category in Portuguese. Used to group delivery performance by category. |
| `product_name_lenght` | text | Not carried into current Silver table | Source spelling is `lenght`. Length of the product name field in the original dataset. |
| `product_description_lenght` | text | Not carried into current Silver table | Source spelling is `lenght`. Length of the product description field. |
| `product_photos_qty` | text | Not carried into current Silver table | Number of product photos recorded. |
| `product_weight_g` | text | Not carried into current Silver table | Product weight in grams. |
| `product_length_cm` | text | Not carried into current Silver table | Product length in centimeters. |
| `product_height_cm` | text | Not carried into current Silver table | Product height in centimeters. |
| `product_width_cm` | text | Not carried into current Silver table | Product width in centimeters. |

The current Silver script keeps only `product_id` and `product_category_name`. The remaining source columns are still present in Bronze but are not available in the current Silver/Gold reporting model.

### Sellers — `olist_sellers_dataset.csv`

Bronze table: `bronze.olist_sellers_dataset`  
Silver table: `silver.sellers`  
Source/Silver rows: 3,095

| Field | Bronze type | Silver type | Meaning |
|---|---|---|---|
| `seller_id` | text | text, primary key | Seller identifier. |
| `seller_zip_code_prefix` | text | text | Seller ZIP-code prefix. Kept as text. |
| `seller_city` | text | text | Seller city. |
| `seller_state` | text | text | Seller state abbreviation. Used for seller-state delivery comparisons. |

### Product category translation — `product_category_name_translation.csv`

Bronze table: `bronze.product_category_name_translation`  
Silver table: `silver.product_category_translation`  
Source/Silver rows: 71

| Field | Bronze type | Silver type | Meaning |
|---|---|---|---|
| `product_category_name` | text | text, primary key | Portuguese category name; join key to the product category. |
| `product_category_name_english` | text | text | English translation of the category name. Some products may not get an English label through the translation join, so the Portuguese field is retained for a more complete category analysis. |

### Geolocation — `olist_geolocation_dataset.csv` (not loaded)

The file is present in the source folder but was not loaded into Bronze, Silver, or Gold in this project version.

| Field | Source type/status | Meaning |
|---|---|---|
| `geolocation_zip_code_prefix` | source value; not loaded | ZIP-code prefix associated with the coordinate record. |
| `geolocation_lat` | source value; not loaded | Latitude. |
| `geolocation_lng` | source value; not loaded | Longitude. |
| `geolocation_city` | source value; not loaded | City associated with the ZIP prefix. |
| `geolocation_state` | source value; not loaded | State abbreviation associated with the ZIP prefix. |

## Gold reporting fields

### `gold.fact_orders`

One row per order. It is used for order-level delivery and customer analysis.

| Field | Type | Meaning |
|---|---|---|
| `order_id` | text, primary key | Unique order. |
| `customer_id` | text | Customer record linked to the order. |
| `customer_unique_id` | text | Cross-record customer identifier used for repeat customers. |
| `customer_state` | text | Customer state. |
| `order_status` | text | Order status. |
| `order_purchase_timestamp` | timestamp | Purchase time. |
| `order_approved_at` | timestamp | Approval time; may be null. |
| `order_delivered_carrier_date` | timestamp | Carrier handoff time; may be null. |
| `order_delivered_customer_date` | timestamp | Customer delivery time; may be null. |
| `order_estimated_delivery_date` | timestamp | Estimated delivery time/date. |
| `purchase_to_carrier_hours` | numeric | Hours from purchase to carrier handoff, rounded to two decimals; null if either timestamp is missing. |
| `purchase_to_delivery_hours` | numeric | Hours from purchase to customer delivery, rounded to two decimals; null if either timestamp is missing. |
| `delivered_on_time` | boolean | `TRUE` when eligible and delivered on/before estimate; `FALSE` when eligible and late; `NULL` when not eligible. |

The duration calculations use `(later timestamp - purchase timestamp)` in seconds divided by 3,600. The on-time calculation is only made when `order_status = 'delivered'` and both actual and estimated customer-delivery dates exist.

### `gold.fact_order_items`

One row per order item. It supports item amount, category, seller, and delivery comparisons. Several fields are copied from the related order and therefore repeat for each item in that order.

| Field | Type | Meaning |
|---|---|---|
| `order_id` | text | Related order. |
| `order_item_id` | integer | Item sequence within the order. Together with `order_id`, the primary key. |
| `product_id` | text | Product identifier. |
| `product_category_name` | text | Portuguese category name. |
| `product_category_name_english` | text | English category translation; can be null when no mapping is available. |
| `seller_id` | text | Seller responsible for the item. |
| `seller_state` | text | Seller state abbreviation. |
| `customer_state` | text | Customer state abbreviation. |
| `price` | numeric(12,2) | Item price in BRL. |
| `freight_value` | numeric(12,2) | Item freight in BRL. |
| `order_status` | text | Related order status. |
| `order_purchase_timestamp` | timestamp | Related order purchase time. |
| `order_delivered_customer_date` | timestamp | Related actual delivery time. |
| `order_estimated_delivery_date` | timestamp | Related estimated delivery time. |
| `purchase_to_delivery_hours` | numeric | Related purchase-to-delivery duration in hours. |
| `delivered_on_time` | boolean | Related order's on-time result. |

An order can contain items from several products, categories, or sellers. In a category/seller visual, distinct order counts are calculated within each group. The same order may therefore appear in more than one group; group totals should not be added as if groups were mutually exclusive.

### `gold.v_order_experience`

One row per order, combining `gold.fact_orders` with the payment and review summaries. This is the main order-level Power BI table.

| Field | Type | Meaning |
|---|---|---|
| `order_id` | text | Unique order identifier. |
| `customer_id` | text | Customer record for the order. |
| `customer_unique_id` | text | Customer identifier used to count repeat customers. |
| `customer_state` | text | Customer state. |
| `order_status` | text | Order status. |
| `order_purchase_timestamp` | timestamp | Purchase time. |
| `order_approved_at` | timestamp | Approval time. |
| `order_delivered_carrier_date` | timestamp | Carrier handoff time. |
| `order_delivered_customer_date` | timestamp | Actual customer delivery time. |
| `order_estimated_delivery_date` | timestamp | Estimated customer delivery time. |
| `purchase_to_carrier_hours` | numeric | Purchase-to-carrier duration in hours. |
| `purchase_to_delivery_hours` | numeric | Purchase-to-customer-delivery duration in hours. |
| `delivered_on_time` | boolean | On-time result; null when the order is not eligible. |
| `payment_record_count` | bigint | Number of payment rows summarized for the order; null when no payment summary exists. |
| `total_payment_value` | numeric | Total payment amount in BRL; null when no payment summary exists. |
| `review_row_count` | bigint | Number of review rows summarized for the order; null when no review summary exists. |
| `scored_review_count` | bigint | Number of review rows with scores; null when no review summary exists. |
| `average_review_score` | numeric | Average review score for the order; null when there is no scored review. |

The expected relationship from this table to `gold.fact_order_items` is one-to-many on `order_id`: one order row can relate to several item rows.

## Power BI measure dictionary

These are the main measures used by the dashboard. Full DAX expressions and explanations are in [Project_Documentation.md](Project_Documentation.md).

| Measure | Table | Definition in plain language |
|---|---|---|
| `Total Orders` | `gold v_order_experience` | Distinct count of orders in the current filters. |
| `Eligible Delivered Orders` | `gold v_order_experience` | Delivered orders with both actual and estimated delivery dates. |
| `On-time Orders` | `gold v_order_experience` | Distinct eligible orders marked on time. |
| `On-time Delivery %` | `gold v_order_experience` | On-time orders divided by eligible delivered orders. |
| `Average Purchase-to-Delivery Days` | `gold v_order_experience` | Average delivery duration for delivered orders, converted from hours to days. |
| `Average Purchase-to-Carrier Hours` | `gold v_order_experience` | Average time from purchase to carrier handoff. |
| `Average Order Review Score` | `gold v_order_experience` | Average order-level review score. |
| `Orders With Review` | `gold v_order_experience` | Distinct orders with a review score. |
| `Payment Value (BRL)` | `gold v_order_experience` | Sum of payment totals at order grain. |
| `Repeat Customers` | `gold v_order_experience` | Distinct customers with more than one order, using `customer_unique_id`. |
| `On-time Orders by Item Group` | `gold fact_order_items` | Distinct on-time orders in the current seller/category context. |
| `Late Orders by Item Group` | `gold fact_order_items` | Distinct late orders in the current seller/category context. |
| `Eligible Delivered Orders by Item Group` | `gold fact_order_items` | On-time plus late distinct orders in the current seller/category context. |
| `On-Time Delivery % by Item Group` | `gold fact_order_items` | On-time orders divided by on-time plus late orders in the group. |
| `Total Item Price (BRL)` | `gold fact_order_items` | Sum of item prices. |
| `Total Freight Value (BRL)` | `gold fact_order_items` | Sum of freight amounts at item grain. |

## Interpretation notes

- A blank `delivered_on_time` is not the same as late. It means the order is outside the eligible on-time comparison, often because it was not delivered or a required date is missing.
- The overall delivery check found 96,478 delivered orders, 96,470 eligible delivered orders, 88,644 on-time orders, and 7,826 late orders. The on-time rate was 91.89%.
- A seller or category with one or two eligible orders can show 100% or 0% by chance. Always show its eligible-order count beside the percentage and be cautious about rankings.
- A seller-state result counts distinct orders associated with sellers in that state. If an order contains items from sellers in different states, that order can appear in more than one seller-state group.
- Payment belongs at order grain; price and freight belong at item grain. Do not sum a payment value repeated across item rows.
- `review_id` is not unique by itself. Do not remove repeated review IDs unless the duplicate logic also considers the related order and review records.
- The current Silver product table only carries product ID and category name. Product name/description lengths, photo count, weight, and dimensions remain in Bronze and are not available in Gold.
- The `gold.v_order_experience` view is in the current database/model. Its `CREATE VIEW` statement was not found in the saved SQL files, so saving that statement in the SQL folder would make the project easier to rebuild.
