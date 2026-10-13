-- ==================================================================
-- Food Ordering and Delivery System - SAMPLE DATA
-- File: sample_data.sql
--
-- Loads EXACTLY the 11 existing menu items with their exact prices.
-- Prices are in rupees (INR) and must not be changed.
--
-- SAFE TO RE-RUN: if a row with the same name already exists it is
-- left completely untouched (the ON DUPLICATE KEY UPDATE below is a
-- deliberate no-op), so running this file 100 times still leaves
-- exactly 11 menu items - no duplicates are ever created.
--
-- Run it with (PowerShell, from this folder):
--   & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p -e "source ./sample_data.sql"
-- ==================================================================

USE food_ordering_db;

INSERT INTO food_items (name, price, is_available) VALUES
  ('pizza',        150.00, 1),
  ('burger',        50.00, 1),
  ('dosa',          70.00, 1),
  ('biriyani',      65.00, 1),
  ('chips',         25.00, 1),
  ('coldrink',      35.00, 1),
  ('cold coffee',   40.00, 1),
  ('french fries',  45.00, 1),
  ('dal makhni',    82.00, 1),
  ('patties',       44.00, 1),
  ('popcorn',       55.00, 1)
ON DUPLICATE KEY UPDATE item_id = item_id;   -- no-op: keep the existing row exactly as-is
