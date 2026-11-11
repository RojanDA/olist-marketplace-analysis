-- silver.orders table from bronze
CREATE TABLE silver.orders AS
SELECT
	NULLIF(BTRIM(order_id), '') AS order_id,
	NULLIF(BTRIM(customer_id), '') AS customer_id,
	NULLIF(BTRIM(order_status), '') AS order_status,
	NULLIF(BTRIM(order_purchase_timestamp), '')::timestamp AS order_purchase_timestamp,
	NULLIF(BTRIM(order_approved_at), '')::timestamp AS order_approved_at,
	NULLIF(BTRIM(order_delivered_carrier_date), '')::timestamp AS order_delivered_carrier_date,
	NULLIF(BTRIM(order_delivered_customer_date), '')::timestamp AS order_delivered_customer_date,
    NULLIF(BTRIM(order_estimated_delivery_date), '')::timestamp AS order_estimated_delivery_date
FROM bronze.olist_orders_dataset;
-- Adding a key to the cleaned table.
ALTER TABLE silver.orders
ADD PRIMARY KEY(order_id);

SELECT 
	COUNT(*) AS silver_order_rows
FROM silver.orders;

SELECT 
	column_name,
	data_type
FROM information_schema.columns
WHERE table_schema = 'silver'
	AND table_name = 'orders'
ORDER BY ordinal_position;

-- silver.customers table from bronze
CREATE TABLE silver.customers AS 
SELECT
	NULLIF(BTRIM(customer_id), '') AS customer_id,
	NULLIF(BTRIM(customer_unique_id), '') AS customer_unique_id,
	NULLIF(BTRIM(customer_zip_code_prefix), '') AS customer_zip_code_prefix,
	NULLIF(BTRIM(customer_city), '') AS customer_city,
	NULLIF(BTRIM(customer_state), '') AS customer_state
FROM bronze.olist_customers_dataset;
-- Adding a key to the cleaned table.
ALTER TABLE silver.customers 
ADD PRIMARY KEY (customer_id); 

-- silver.products table from bronze
CREATE TABLE silver.products AS 
SELECT
    NULLIF(BTRIM(product_id), '') AS product_id, 
    NULLIF(BTRIM(product_category_name), '') AS product_category_name 
FROM bronze.olist_products_dataset; 

-- Adding a key to the cleaned table.
ALTER TABLE silver.products 
ADD PRIMARY KEY (product_id);


-- Create the cleaned sellers table from bronze.
CREATE TABLE silver.sellers AS 
SELECT
    NULLIF(BTRIM(seller_id), '') AS seller_id, 
    NULLIF(BTRIM(seller_zip_code_prefix), '') AS seller_zip_code_prefix, 
    NULLIF(BTRIM(seller_city), '') AS seller_city, 
    NULLIF(BTRIM(seller_state), '') AS seller_state 
FROM bronze.olist_sellers_dataset; 
-- Add a key to the cleaned table.
ALTER TABLE silver.sellers 
ADD PRIMARY KEY (seller_id); 

-- Create the cleaned order-items table from bronze.
CREATE TABLE silver.order_items AS 
SELECT
    NULLIF(BTRIM(order_id), '') AS order_id, 
    NULLIF(BTRIM(order_item_id), '')::integer AS order_item_id, 
    NULLIF(BTRIM(product_id), '') AS product_id,
    NULLIF(BTRIM(seller_id), '') AS seller_id, 
    NULLIF(BTRIM(shipping_limit_date), '')::timestamp AS shipping_limit_date, 
    NULLIF(BTRIM(price), '')::numeric(12, 2) AS price, 
    NULLIF(BTRIM(freight_value), '')::numeric(12, 2) AS freight_value 
FROM bronze.olist_order_items_dataset; 
-- Add a key to the cleaned table.
ALTER TABLE silver.order_items 
ADD PRIMARY KEY (order_id, order_item_id); 


-- Create the cleaned payments table.
CREATE TABLE silver.order_payments AS 
SELECT
    NULLIF(BTRIM(order_id), '') AS order_id, 
    NULLIF(BTRIM(payment_sequential), '')::integer AS payment_sequential,
    NULLIF(BTRIM(payment_type), '') AS payment_type, 
    NULLIF(BTRIM(payment_installments), '')::integer AS payment_installments, 
    NULLIF(BTRIM(payment_value), '')::numeric(12, 2) AS payment_value 
FROM bronze.olist_order_payments_dataset; 

ALTER TABLE silver.order_payments 
ADD PRIMARY KEY (order_id, payment_sequential); 


-- Create the cleaned reviews table.
CREATE TABLE silver.order_reviews AS 
SELECT
    NULLIF(BTRIM(review_id), '') AS review_id, 
    NULLIF(BTRIM(order_id), '') AS order_id, 
    NULLIF(BTRIM(review_score), '')::integer AS review_score, 
    NULLIF(BTRIM(review_comment_title), '') AS review_comment_title,
    NULLIF(BTRIM(review_comment_message), '') AS review_comment_message, 
    NULLIF(BTRIM(review_creation_date), '')::timestamp AS review_creation_date, 
    NULLIF(BTRIM(review_answer_timestamp), '')::timestamp AS review_answer_timestamp 
FROM bronze.olist_order_reviews_dataset; 



-- Create the cleaned category translation table.
CREATE TABLE silver.product_category_translation AS 
SELECT
    NULLIF(BTRIM(product_category_name), '') AS product_category_name,
    NULLIF(BTRIM(product_category_name_english), '') AS product_category_name_english 
FROM bronze.product_category_name_translation;
ALTER TABLE silver.product_category_translation 
ADD PRIMARY KEY (product_category_name); 