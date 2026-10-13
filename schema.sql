-- ==================================================================
-- Food Ordering and Delivery System - DATABASE SCHEMA
-- File: schema.sql            Engine: MySQL 8.0.16+ (InnoDB)
--
-- Creates:
--   database food_ordering_db
--   table  food_items     (the menu)
--   table  customers      (who orders)
--   table  orders         (one row per order)
--   table  order_details  (the dishes inside each order)
--
-- Safe to re-run: every CREATE uses IF NOT EXISTS, so running this
-- file again on an existing database changes nothing.
--
-- Run it with (PowerShell, from this folder):
--   & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p -e "source ./schema.sql"
-- ==================================================================

-- ------------------------------------------------------------------
-- 1. The database
-- ------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS food_ordering_db
  CHARACTER SET utf8mb4        -- full Unicode (food names in any language)
  COLLATE utf8mb4_0900_ai_ci;  -- MySQL 8 default collation

USE food_ordering_db;

-- ------------------------------------------------------------------
-- 2. food_items - the menu
--    One row per dish.
--    name        UNIQUE  -> the same dish cannot be added twice
--    price       DECIMAL -> exact money; CHECK keeps it >= 0
--    is_available        -> 1 = on the menu, 0 = sold out (soft flag:
--                           the row and its price history are kept)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS food_items (
  item_id      INT AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(100)  NOT NULL UNIQUE,
  price        DECIMAL(10,2) NOT NULL,
  is_available TINYINT(1)    NOT NULL DEFAULT 1,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_food_items_price CHECK (price >= 0),
  CONSTRAINT chk_food_items_name  CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE = InnoDB;

-- ------------------------------------------------------------------
-- 3. customers - who is ordering
--    phone / email / address are OPTIONAL (NULL allowed).
--    If given, each phone and each email may be stored only once.
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  phone       VARCHAR(20)  UNIQUE,
  email       VARCHAR(255) UNIQUE,
  address     TEXT,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_customers_name CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE = InnoDB;

-- ------------------------------------------------------------------
-- 4. orders - one row per order
--    customer_id -> FOREIGN KEY to customers.
--      ON DELETE RESTRICT: a customer who has orders cannot be
--      deleted, so order history is never lost by accident.
--      ON UPDATE CASCADE : if a customer_id ever changes, the
--      orders automatically follow it.
--    status       -> only the listed values may be stored.
--    total_amount -> the order's grand total (>= 0).
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  order_id     INT AUTO_INCREMENT PRIMARY KEY,
  customer_id  INT           NOT NULL,
  order_date   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status       VARCHAR(20)   NOT NULL DEFAULT 'placed',
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_orders_total CHECK (total_amount >= 0),
  CONSTRAINT chk_orders_status
    CHECK (status IN ('placed','preparing','out_for_delivery','delivered','cancelled')),
  -- Indexes for the common lookups (MySQL auto-indexes FK columns):
  INDEX idx_orders_status_date (status, order_date),   -- delivered-sales report
  INDEX idx_orders_order_date  (order_date)            -- date-range reports
) ENGINE = InnoDB;

-- ------------------------------------------------------------------
-- 5. order_details - the dishes inside one order (line items)
--    order_id -> FOREIGN KEY to orders (RESTRICT: order history kept)
--    item_id  -> FOREIGN KEY to food_items (RESTRICT: a dish that has
--                been ordered cannot be deleted - mark it unavailable)
--    quantity   > 0
--    unit_price >= 0 -> the menu price AT THE TIME OF PURCHASE, so
--                later menu-price changes never rewrite history
--    subtotal   >= 0 -> normally quantity * unit_price
--    (order_id, item_id) is UNIQUE: one dish once per order -
--    increase the quantity instead of adding a second row.
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_details (
  order_detail_id INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  order_id        INT           NOT NULL,
  item_id         INT           NOT NULL,
  quantity        INT           NOT NULL,
  unit_price      DECIMAL(10,2) NOT NULL,
  subtotal        DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_order_details_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_order_details_item
    FOREIGN KEY (item_id) REFERENCES food_items (item_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT uq_order_details_order_item UNIQUE (order_id, item_id),
  CONSTRAINT chk_order_details_quantity   CHECK (quantity > 0),
  CONSTRAINT chk_order_details_unit_price CHECK (unit_price >= 0),
  CONSTRAINT chk_order_details_subtotal   CHECK (subtotal >= 0)
) ENGINE = InnoDB;

-- ==================================================================
-- TABLE RELATIONSHIPS IN PLAIN LANGUAGE
--
--   customers  1 --< orders         one customer can place many orders
--   orders     1 --< order_details  one order can contain many dishes
--   food_items 1 --< order_details  one dish can appear in many orders
--
--   order_details is the "link" table between orders and food_items.
--   Deleting is BLOCKED (RESTRICT) whenever another table still
--   references the row, so historical order information is protected.
-- ==================================================================
