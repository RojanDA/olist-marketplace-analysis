
-- Create the Gold table at one row per order.
-- Source  : silver.orders  +  silver.customers  
CREATE TABLE gold.fact_orders AS
SELECT
    orders.order_id,
    orders.customer_id,
    customers.customer_unique_id,
    customers.customer_state,
    orders.order_status,
    orders.order_purchase_timestamp,
    orders.order_approved_at,
    orders.order_delivered_carrier_date,
    orders.order_delivered_customer_date,
    orders.order_estimated_delivery_date,
    ROUND(
        EXTRACT(EPOCH FROM (
            orders.order_delivered_carrier_date
            - orders.order_purchase_timestamp
        )) / 3600.0,
        2
    ) AS purchase_to_carrier_hours,
    ROUND(
        EXTRACT(EPOCH FROM (
            orders.order_delivered_customer_date
            - orders.order_purchase_timestamp
        )) / 3600.0,
        2
    ) AS purchase_to_delivery_hours,
    CASE
        WHEN orders.order_status = 'delivered'
         AND orders.order_delivered_customer_date IS NOT NULL
         AND orders.order_estimated_delivery_date IS NOT NULL
        THEN orders.order_delivered_customer_date
             <= orders.order_estimated_delivery_date
        ELSE NULL
    END AS delivered_on_time
FROM silver.orders AS orders
JOIN silver.customers AS customers
    ON orders.customer_id = customers.customer_id;

ALTER TABLE gold.fact_orders
ADD PRIMARY KEY (order_id);

-- GOLD LAYER: fact_order_items
-- Purpose : Build an analysis-ready fact table with exactly ONE ROW PER ORDER ITEM.
-- Source  : silver.order_items, silver.products, silver.sellers,
--           silver.product_category_translation  +  gold.fact_orders
-- CTAS builds and populates the table in one step. Column names/types are
-- inferred from the SELECT list below.
CREATE TABLE gold.fact_order_items AS
SELECT
    items.order_id,
    items.order_item_id,
    items.product_id,
    products.product_category_name,
    translations.product_category_name_english,
    items.seller_id,
    sellers.seller_state,
    orders.customer_state,
    items.price,
    items.freight_value,
    orders.order_status,
    orders.order_purchase_timestamp,
    orders.order_delivered_customer_date,
    orders.order_estimated_delivery_date,
    orders.purchase_to_delivery_hours,
    orders.delivered_on_time
FROM silver.order_items AS items
JOIN gold.fact_orders AS orders
    ON items.order_id = orders.order_id
JOIN silver.products AS products
    ON items.product_id = products.product_id
JOIN silver.sellers AS sellers
    ON items.seller_id = sellers.seller_id
LEFT JOIN silver.product_category_translation AS translations
    ON products.product_category_name = translations.product_category_name;

ALTER TABLE gold.fact_order_items
ADD PRIMARY KEY (order_id, order_item_id);

-- GOLD LAYER: order_payment_summary
-- Purpose : Collapse the many-to-one payment records into a SINGLE ROW PER ORDER
--           so payment info can be joined to fact_orders without multiplying rows.

CREATE TABLE gold.order_payment_summary AS
SELECT
    order_id,
    COUNT(*) AS payment_record_count,
    SUM(payment_value) AS total_payment_value
FROM silver.order_payments
GROUP BY order_id;

ALTER TABLE gold.order_payment_summary
ADD PRIMARY KEY (order_id);

-- only 99440 row added 1 row is meassing in above so we will check.
-- This show an order that has no payment summary.
SELECT
    orders.order_id, 
    orders.order_status 
FROM silver.orders AS orders 
LEFT JOIN gold.order_payment_summary AS payments
    ON orders.order_id = payments.order_id 
WHERE payments.order_id IS NULL;
-- OUTPUT : one missing order : bfbd0f9bdef84302105ad712db648a6c, which is marked delivered


-- Some orders have multiple review rows. 
-- This table groups those rows by order_id and 
-- calculates the average score, giving us one review summary per order.
CREATE TABLE gold.order_review_summary AS
SELECT
    order_id,
    COUNT(*) AS review_row_count,
    COUNT(review_score) AS scored_review_count,
    ROUND(AVG(review_score), 2) AS average_review_score
FROM silver.order_reviews
GROUP BY order_id;

ALTER TABLE gold.order_review_summary
ADD PRIMARY KEY (order_id);

