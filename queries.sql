-- ==================================================================
-- Food Ordering and Delivery System - EXAMPLE QUERIES
-- File: queries.sql
--
-- Every example below is COMMENTED OUT with "--" so this file is
-- safe to run as-is (running it changes nothing).
-- To try an example: copy it, remove the "--" markers, and paste it
-- into the mysql client. Enter the client first:
--   & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p food_ordering_db
-- ==================================================================

USE food_ordering_db;

-- ------------------------------------------------------------
-- 1. FOOD ITEMS: insert / view / update / delete
-- ------------------------------------------------------------
-- INSERT a new menu item (price must be >= 0):
-- INSERT INTO food_items (name, price, is_available)
-- VALUES ('samosa', 30.00, 1);

-- VIEW the whole menu, cheapest first:
-- SELECT item_id, name, price, is_available
-- FROM food_items
-- ORDER BY price ASC;

-- VIEW only items currently available:
-- SELECT item_id, name, price
-- FROM food_items
-- WHERE is_available = 1;

-- UPDATE a price (e.g. pizza 150 -> 160):
-- UPDATE food_items SET price = 160.00 WHERE item_id = 1;

-- Mark an item sold out (soft delete - keeps the row and its
-- order history; a hard DELETE is blocked once it has been ordered):
-- UPDATE food_items SET is_available = 0 WHERE item_id = 6;

-- DELETE an item (only works if no order_details references it):
-- DELETE FROM food_items WHERE item_id = 12;

-- ------------------------------------------------------------
-- 2. CUSTOMERS: insert / view
-- ------------------------------------------------------------
-- INSERT a customer (phone / email / address are all optional):
-- INSERT INTO customers (name, phone, email, address)
-- VALUES ('Ravi Kumar', '9876543210', 'ravi@example.com',
--         '12 MG Road, Bengaluru');

-- INSERT a customer with no contact information at all:
-- INSERT INTO customers (name) VALUES ('Walk-in Customer');

-- VIEW all customers:
-- SELECT customer_id, name, phone, email, address FROM customers;

-- ------------------------------------------------------------
-- 3. ORDERS: create an order and add order details
-- ------------------------------------------------------------
-- Step 1: create the order header (total_amount starts at 0.00):
-- INSERT INTO orders (customer_id) VALUES (1);

-- Step 2: add line items. unit_price = menu price AT PURCHASE TIME.
-- quantity must be > 0; subtotal = quantity * unit_price.
-- INSERT INTO order_details (order_id, item_id, quantity, unit_price, subtotal)
-- VALUES (1, 1, 2, 150.00, 300.00);   -- 2 pizzas
--
-- INSERT INTO order_details (order_id, item_id, quantity, unit_price, subtotal)
-- VALUES (1, 6, 1, 35.00, 35.00);     -- 1 coldrink

-- Step 3: store the calculated total on the order:
-- UPDATE orders o
-- JOIN (
--   SELECT order_id, SUM(subtotal) AS grand_total
--   FROM order_details
--   GROUP BY order_id
-- ) d ON d.order_id = o.order_id
-- SET o.total_amount = d.grand_total;

-- ------------------------------------------------------------
-- 4. VIEW ORDER DETAILS WITH FOOD NAMES AND CUSTOMER NAMES (JOINs)
-- ------------------------------------------------------------
-- SELECT o.order_id, c.name AS customer_name, f.name AS food_name,
--        od.quantity, od.unit_price, od.subtotal
-- FROM order_details od
-- JOIN orders     o ON o.order_id    = od.order_id
-- JOIN customers  c ON c.customer_id = o.customer_id
-- JOIN food_items f ON f.item_id     = od.item_id
-- ORDER BY o.order_id, od.order_detail_id;

-- ------------------------------------------------------------
-- 5. CALCULATE ORDER TOTALS
-- ------------------------------------------------------------
-- Per order (calculated total vs the stored total, to check for drift):
-- SELECT o.order_id, c.name AS customer_name,
--        COALESCE(SUM(od.subtotal), 0.00) AS calculated_total,
--        o.total_amount                    AS stored_total,
--        COALESCE(SUM(od.subtotal), 0.00) - o.total_amount AS difference
-- FROM orders o
-- JOIN customers c ON c.customer_id = o.customer_id
-- LEFT JOIN order_details od ON od.order_id = o.order_id
-- GROUP BY o.order_id, c.name, o.total_amount;

-- Per dish (how many sold and the revenue), all time:
-- SELECT f.name, SUM(od.quantity) AS qty_sold, SUM(od.subtotal) AS revenue
-- FROM order_details od
-- JOIN food_items f ON f.item_id = od.item_id
-- GROUP BY f.name
-- ORDER BY revenue DESC;

-- ------------------------------------------------------------
-- 6. DELIVERED-ORDER SALES
-- ------------------------------------------------------------
-- Every delivered order with its customer:
-- SELECT o.order_id, c.name AS customer_name, o.order_date, o.total_amount
-- FROM orders o
-- JOIN customers c ON c.customer_id = o.customer_id
-- WHERE o.status = 'delivered'
-- ORDER BY o.order_date DESC;

-- Total delivered sales:
-- SELECT COUNT(*) AS delivered_orders,
--        COALESCE(SUM(total_amount), 0.00) AS delivered_sales
-- FROM orders
-- WHERE status = 'delivered';

-- Daily delivered sales:
-- SELECT DATE(order_date) AS order_day,
--        COUNT(*) AS orders,
--        COALESCE(SUM(total_amount), 0.00) AS sales
-- FROM orders
-- WHERE status = 'delivered'
-- GROUP BY DATE(order_date)
-- ORDER BY order_day;

-- ------------------------------------------------------------
-- 7. COMMIT AND ROLLBACK DEMONSTRATION
-- ------------------------------------------------------------
-- Turn off auto-commit, make a change, then UNDO it:
-- START TRANSACTION;
-- INSERT INTO food_items (name, price) VALUES ('test item', 99.00);
-- SELECT COUNT(*) AS with_test_item FROM food_items;   -- includes 'test item'
-- ROLLBACK;                                            -- undo the insert
-- SELECT COUNT(*) AS after_rollback FROM food_items;   -- 'test item' is gone

-- To make changes permanent instead of undoing them:
-- START TRANSACTION;
-- INSERT INTO food_items (name, price) VALUES ('permanent item', 10.00);
-- COMMIT;                                              -- saved for good

-- ------------------------------------------------------------
-- 8. INSPECT ALL FOUR TABLES
-- ------------------------------------------------------------
-- SHOW TABLES;                       -- list the tables in this database
-- DESCRIBE food_items;               -- columns and types of one table
-- DESCRIBE customers;
-- DESCRIBE orders;
-- DESCRIBE order_details;
-- SELECT * FROM food_items;          -- every row of each table
-- SELECT * FROM customers;
-- SELECT * FROM orders;
-- SELECT * FROM order_details;

-- Row counts of all four tables at once:
-- SELECT 'food_items'      AS table_name, COUNT(*) AS row_count FROM food_items
-- UNION ALL
-- SELECT 'customers',      COUNT(*) FROM customers
-- UNION ALL
-- SELECT 'orders',         COUNT(*) FROM orders
-- UNION ALL
-- SELECT 'order_details',  COUNT(*) FROM order_details;
