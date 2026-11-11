-- 1. Orders: row count and missing key fields / timestamps.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_id), '') IS NULL
	) AS missing_order_id,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(customer_id), '') IS NULL
	) AS missing_customer_id,
    COUNT(*) FILTER (	
		WHERE NULLIF(BTRIM(order_status), '') IS NULL
	) AS missing_order_status,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_purchase_timestamp), '') IS NULL
	) AS missing_purchase_timestamp,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_approved_at), '') IS NULL
	) AS missing_approved_at,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NULL
	) AS missing_carrier_date,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_delivered_customer_date), '') IS NULL
	) AS missing_customer_delivery_date,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_estimated_delivery_date), '') IS NULL
	) AS missing_estimated_delivery_date
FROM bronze.olist_orders_dataset;
-- Observed: 99,441 rows; missing approval=160, carrier handoff=1,783,
-- customer delivery=2,965. Other listed order fields had no missing values.

-- 2. Orders: compare missing milestone timestamps by order status.
SELECT
    order_status,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_approved_at), '') IS NULL
	) AS missing_approved_at,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NULL
	) AS missing_carrier_date,
    COUNT(*) FILTER (
		WHERE NULLIF(BTRIM(order_delivered_customer_date), '') IS NULL
	) AS missing_customer_delivery_date
FROM bronze.olist_orders_dataset
GROUP BY order_status
ORDER BY order_status;
-- Observed: missing milestones vary by status. Some delivered orders also have
-- missing approval, carrier, or customer-delivery timestamps; investigate before KPI use.

-- 3. Check the expected unique order key.
SELECT order_id, COUNT(*) AS rows_per_id
FROM bronze.olist_orders_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
LIMIT 10;
-- Observed: no rows; order_id was unique in the orders table.

-- 4. Check the expected order-item key: order_id + order_item_id.
SELECT order_id, order_item_id, COUNT(*) AS rows_per_key
FROM bronze.olist_order_items_dataset
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1
LIMIT 10;
-- Observed: no rows; no duplicate order-item key pairs.

-- 5. Check the expected payment key: order_id + payment_sequential.
SELECT order_id, payment_sequential, COUNT(*) AS rows_per_key
FROM bronze.olist_order_payments_dataset
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1
LIMIT 10;
-- Observed: no rows; no duplicate payment key pairs.

-- 6. Review findings: review_id repeats, so do not deduplicate by review_id alone.
SELECT review_id, COUNT(*) AS rows_per_id
FROM bronze.olist_order_reviews_dataset
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY rows_per_id DESC
LIMIT 10;
-- Observed from the full duplicate-key summary: 789 repeated review IDs and
-- 814 extra rows. Sample repeated IDs were associated with different orders.

-- Review rows per order: multiple rows can exist for an order.
SELECT order_id, COUNT(*) AS review_rows
FROM bronze.olist_order_reviews_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
LIMIT 10;
-- Observed: sample orders had two or three review rows. Handle review grain
-- carefully when joining to orders or summarizing review scores.

-- 7. Customer identifiers: customer_id is a record key; customer_unique_id
-- identifies the same customer across records and can repeat.
SELECT customer_id, COUNT(*) AS rows_per_id
FROM bronze.olist_customers_dataset
GROUP BY customer_id
HAVING COUNT(*) > 1
LIMIT 10;
-- Observed: no repeated customer_id values.

SELECT customer_unique_id, COUNT(*) AS customer_records
FROM bronze.olist_customers_dataset
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY customer_records DESC
LIMIT 10;
-- Observed: customer_unique_id repeats, as expected for repeat-customer analysis.

-- 8. Check dimension keys used by item and category joins.
SELECT product_id, COUNT(*) AS rows_per_id
FROM bronze.olist_products_dataset
GROUP BY product_id
HAVING COUNT(*) > 1
LIMIT 10;
-- Observed: no repeated product_id values.

SELECT seller_id, COUNT(*) AS rows_per_id
FROM bronze.olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT(*) > 1
LIMIT 10;
-- Observed: no repeated seller_id values.

SELECT product_category_name, COUNT(*) AS rows_per_category
FROM bronze.product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1
LIMIT 10;
-- Observed: no repeated category names in the translation table.

-- 9. Essential relationship checks: unmatched rows should not be silently lost in joins.
SELECT items.order_id
FROM bronze.olist_order_items_dataset AS items
LEFT JOIN bronze.olist_orders_dataset AS orders
    ON items.order_id = orders.order_id
WHERE orders.order_id IS NULL
LIMIT 10;
-- Observed: no unmatched order items.

SELECT items.product_id
FROM bronze.olist_order_items_dataset AS items
LEFT JOIN bronze.olist_products_dataset AS products
    ON items.product_id = products.product_id
WHERE products.product_id IS NULL
LIMIT 10;
-- Observed: no unmatched product IDs.

SELECT items.seller_id
FROM bronze.olist_order_items_dataset AS items
LEFT JOIN bronze.olist_sellers_dataset AS sellers
    ON items.seller_id = sellers.seller_id
WHERE sellers.seller_id IS NULL
LIMIT 10;
-- Observed: no unmatched seller IDs.

SELECT orders.customer_id
FROM bronze.olist_orders_dataset AS orders
LEFT JOIN bronze.olist_customers_dataset AS customers
    ON orders.customer_id = customers.customer_id
WHERE customers.customer_id IS NULL
LIMIT 10;
-- Observed: no unmatched customer IDs.
