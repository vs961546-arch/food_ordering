# Food Ordering and Delivery System — Database

MySQL database for the Food Ordering and Delivery System project.

**Status: database layer only.** Nothing is connected to the frontend, the
backend, or the C++ DSA code yet. Per the project plan, integration waits
until you have run the scripts below, verified the tables and the 11 menu
items, and confirmed the tests pass.

## Files in this folder

| File | Purpose |
|---|---|
| `schema.sql` | Creates the database `food_ordering_db` and the 4 tables with all constraints and indexes. Safe to re-run. |
| `sample_data.sql` | Loads exactly the 11 existing menu items with their exact prices. Safe to re-run (no duplicates). |
| `queries.sql` | Commented example queries (insert/update/delete, joins, totals, sales, COMMIT/ROLLBACK, table inspection). Nothing runs automatically. |
| `README.md` | This file. |

## 1. Requirements

- **MySQL Community Server 8.0.16 or newer** (CHECK constraints are only
  *enforced* from 8.0.16). Download: <https://dev.mysql.com/downloads/mysql/>
- The `mysql` command-line client.

**Already verified on this PC (no installation needed):**

- MySQL Server 8.0 is installed at
  `C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe`
- The **`MySQL80` service is running** (set to Automatic).
- The `mysql.exe` client is **not in your PATH** — either use the full
  path in every command (used below), or add it to PATH once:

  ```powershell
  [Environment]::SetEnvironmentVariable(
      "Path",
      $env:Path + ";C:\Program Files\MySQL\MySQL Server 8.0\bin",
      "User")
  ```
  Then **close and reopen PowerShell**; `mysql --version` should work.

## 2. Create the database and load the data

Open PowerShell and run these exact commands:

```powershell
# 1. Go to the database folder
cd "C:\Users\vs961\OneDrive\Documents\html\database"

# 2. Shortcut for the client path (skip this if you added it to PATH)
$mysql = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"

# 3. Create the database + 4 tables (you will be prompted for the root password)
& $mysql -u root -p -e "source ./schema.sql"

# 4. Load the 11 menu items (prompts again)
& $mysql -u root -p -e "source ./sample_data.sql"
```

Notes:

- PowerShell does **not** support the `mysql < file.sql` redirection that
  you may see in tutorials. Use `-e "source ./file.sql"` (as above) or
  this pipe instead: `Get-Content .\schema.sql -Raw | & $mysql -u root -p`
- At the `Enter password:` prompt, type the root password and press Enter.
  **Nothing appears on screen while you type — that is normal.**
- If you rename the database, edit the `CREATE DATABASE` / `USE` lines in
  **all three** `.sql` files so they stay in sync.

## 3. Verify all four tables exist

```powershell
& $mysql -u root -p -e "USE food_ordering_db; SHOW TABLES;"
```

Expected output (4 tables):

```
customers
food_items
order_details
orders
```

Inspect the structure of each table:

```powershell
& $mysql -u root -p -e "USE food_ordering_db; DESCRIBE food_items; DESCRIBE customers; DESCRIBE orders; DESCRIBE order_details;"
```

## 4. Verify all 11 menu items and their exact prices

```powershell
& $mysql -u root -p -e "USE food_ordering_db; SELECT item_id, name, price FROM food_items ORDER BY item_id;"
```

Expected result (IDs assume a fresh database):

```
item_id  name          price
-------  ------------  ------
      1  pizza          150.00
      2  burger          50.00
      3  dosa            70.00
      4  biriyani        65.00
      5  chips           25.00
      6  coldrink        35.00
      7  cold coffee     40.00
      8  french fries    45.00
      9  dal makhni      82.00
     10  patties         44.00
     11  popcorn         55.00
```

Strict check — this query must return **0 rows** (empty = every item and
price matches exactly):

```sql
SELECT name, price FROM food_items
WHERE NOT (
  (name = 'pizza'        AND price = 150.00) OR
  (name = 'burger'       AND price =  50.00) OR
  (name = 'dosa'         AND price =  70.00) OR
  (name = 'biriyani'     AND price =  65.00) OR
  (name = 'chips'        AND price =  25.00) OR
  (name = 'coldrink'     AND price =  35.00) OR
  (name = 'cold coffee'  AND price =  40.00) OR
  (name = 'french fries' AND price =  45.00) OR
  (name = 'dal makhni'   AND price =  82.00) OR
  (name = 'patties'      AND price =  44.00) OR
  (name = 'popcorn'      AND price =  55.00)
);
SELECT COUNT(*) AS item_count FROM food_items;   -- must be 11
```

## 5. Test insert, update, delete, primary keys and foreign keys

Paste the following into the client (`& $mysql -u root -p food_ordering_db`).
The happy-path block runs inside a transaction that is rolled back at the
end, so your database stays clean.

```sql
USE food_ordering_db;

-- (A) Successful INSERT / UPDATE / DELETE, then undone:
START TRANSACTION;
INSERT INTO food_items (name, price) VALUES ('test samosa', 30.00);   -- INSERT ok
UPDATE food_items SET price = 31.00 WHERE name = 'test samosa';       -- UPDATE ok
DELETE FROM food_items WHERE name = 'test samosa';                      -- DELETE ok (nothing references it)
ROLLBACK;

-- (B) PRIMARY KEY / UNIQUE: adding 'pizza' again must FAIL
INSERT INTO food_items (name, price) VALUES ('pizza', 150.00);
-- Expected: ERROR 1062 (23000): Duplicate entry 'pizza' for key 'food_items.name'

-- (C) CHECK: a negative price must FAIL
INSERT INTO food_items (name, price) VALUES ('bad item', -10.00);
-- Expected: ERROR 3819 (HY000): Check constraint 'chk_food_items_price' is violated

-- (D) FOREIGN KEY: an order for a customer that does not exist must FAIL
INSERT INTO orders (customer_id) VALUES (99999);
-- Expected: ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails

-- (E) Full order flow + RESTRICT protection (all rolled back):
START TRANSACTION;
INSERT INTO customers (name, phone) VALUES ('Test Customer', '9999999999');
SET @c := LAST_INSERT_ID();
INSERT INTO orders (customer_id) VALUES (@c);
SET @o := LAST_INSERT_ID();
INSERT INTO order_details (order_id, item_id, quantity, unit_price, subtotal)
VALUES (@o, 1, 2, 150.00, 300.00), (@o, 6, 1, 35.00, 35.00);
UPDATE orders o
  JOIN (SELECT order_id, SUM(subtotal) AS t FROM order_details GROUP BY order_id) d
    ON d.order_id = o.order_id
  SET o.total_amount = d.t WHERE o.order_id = @o;
SELECT order_id, total_amount FROM orders WHERE order_id = @o;          -- 335.00
DELETE FROM food_items WHERE item_id = 1;                               -- must FAIL: ERROR 1451 (pizza is referenced)
INSERT INTO order_details (order_id, item_id, quantity, unit_price, subtotal)
VALUES (@o, 3, 0, 70.00, 0.00);                                         -- must FAIL: ERROR 3819 (quantity must be > 0)
ROLLBACK;
```

Each expected error above **is the test passing** — the constraint did its job.

## 6. Common errors and solutions

| Error | Meaning | Solution |
|---|---|---|
| `'mysql' is not recognized...` | client not in PATH | use the full path `& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"` or add it to PATH (step 1) |
| `ERROR 1045 (28000): Access denied for user 'root'@'localhost'` | wrong user or password | retype carefully; if the root password was lost, see "Reset the root password" below |
| `ERROR 1049 (42000): Unknown database 'food_ordering_db'` | schema not created yet | run `schema.sql` first (step 2.3) |
| `ERROR 1062 (23000): Duplicate entry ...` | UNIQUE / PRIMARY KEY violation | the row already exists — UPDATE it instead; `sample_data.sql` is safe to re-run |
| `ERROR 1451 (23000): Cannot delete or update a parent row` | RESTRICT blocked the delete | delete the child rows first, or set `is_available = 0` instead of deleting a dish |
| `ERROR 1452 (23000): Cannot add or update a child row` | FOREIGN KEY violation | the referenced customer/order/item does not exist — create it first |
| `ERROR 3819 (HY000): Check constraint ... is violated` | CHECK violation | negative price, `quantity <= 0`, or an invalid `status` value |
| `ERROR 1064 (42000): syntax error` | SQL typo, or a commented example pasted **with** its `--` markers | remove the `--` markers, check semicolons |
| `ERROR 2003 (HY000): Can't connect to MySQL server` | service stopped | `Start-Service MySQL80` |
| `At the Enter password prompt nothing shows` | normal security behaviour | just type the password and press Enter |

**Reset the root password** (only if lost). In an **admin** PowerShell:

```powershell
Stop-Service MySQL80
# Create C:\temp\reset.txt containing:
#   ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyNewStrongPassword';
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe" --init-file="C:\temp\reset.txt" --console
# When it stops, start the service normally:
Start-Service MySQL80
```

## 7. Entering the database password securely

- **Always** let the client ask: `mysql -u root -p` → type the password at
  the `Enter password:` prompt.
- **Never** put the password on the command line (`mysql -u root -pSecret`) —
  it is saved in the shell history and visible in the process list.
- **Never** store the database password in `.html`, `.css`, `.js`, or `.cpp`
  project files. Frontend code runs on the user's machine and must never
  know database credentials.
- For automated scripts, prefer `--defaults-extra-file` pointing to a
  permissions-restricted `.ini` file, or the `MYSQL_PWD` environment
  variable (still visible to other processes of the same user — the
  interactive prompt is safest).
- Later, when a backend exists, create a dedicated least-privilege user for
  the application instead of using root (backend step — not part of this
  task).

## 8. Table relationships in plain language

```
customers  1 ──< orders         one customer can place many orders
orders     1 ──< order_details  one order can contain many dishes
food_items 1 ──< order_details  one dish can appear in many orders
```

- `order_details` is the link table between `orders` and `food_items`.
- `orders.total_amount` is the grand total for the order; each
  `order_details.subtotal` is `quantity × unit_price` for one dish.
- `unit_price` stores the price **at purchase time**, so changing a menu
  price later never rewrites order history.
- **RESTRICT** on all foreign keys: you cannot delete a customer, an
  order, or a dish that is still referenced by an order — historical
  order information is protected from accidental deletion.

## 9. Test results

All tests below were **actually executed** against `food_ordering_db`
on this machine (MySQL Community Server 8.0.46, Windows 11) on
2026-10-13. **23 checks run — 23 passed, 0 failed.** All test data
was rolled back afterwards: the database contains only the 11 menu
items and zero customer/order rows.

| # | Test | Expected | Actual | Result |
|---|------|----------|--------|--------|
| 1 | `schema.sql` executes | exit code 0 | 0 | PASS |
| 2 | `sample_data.sql` loads menu | 11 items, exact prices | 11 items, exact prices | PASS |
| 3 | `sample_data.sql` re-run (idempotency) | still 11 rows, no duplicates | 11 rows | PASS |
| 4 | Strict price verification | 0 rows | 0 rows | PASS |
| 5 | `SHOW TABLES` | 4 tables | customers, food_items, order_details, orders | PASS |
| 6 | `DESCRIBE` all 4 tables | PK / NOT NULL / UNIQUE / DEFAULT as designed | matches design | PASS |
| 7 | Duplicate food name `pizza` | ERROR 1062 | ERROR 1062: Duplicate entry 'pizza' for key 'food_items.name' | PASS |
| 8 | Negative price (-10.00) | ERROR 3819 | ERROR 3819: chk_food_items_price violated | PASS |
| 9 | Order with customer_id 99999 | ERROR 1452 | ERROR 1452: fk_orders_customer | PASS |
| 10 | Order detail with order_id 99999 | ERROR 1452 | ERROR 1452: fk_order_details_order | PASS |
| 11 | Order detail quantity = 0 | ERROR 3819 | ERROR 3819: chk_order_details_quantity | PASS |
| 12 | Order status 'shipped' (invalid) | ERROR 3819 | ERROR 3819: chk_orders_status | PASS |
| 13 | Order detail with item_id 99999 | ERROR 1452 | ERROR 1452: fk_order_details_item | PASS |
| 14 | COMMIT demo | row saved until deleted | 1 → deleted → 0 | PASS |
| 15 | ROLLBACK demo | 12 → 11 items | 12 → 11 | PASS |
| 16 | Order total (2 pizza + 1 coldrink) | 335.00 | 335.00 | PASS |
| 17 | JOIN: customer + food names | names shown | Test Customer / pizza / coldrink | PASS |
| 18 | Delivered-order sales | 1 order, 335.00 | 1, 335.00 | PASS |
| 19 | DELETE pizza referenced by an order | ERROR 1451 (RESTRICT) | ERROR 1451: fk_order_details_item | PASS |
| 20 | Final row counts | 11 / 0 / 0 / 0 | 11 / 0 / 0 / 0 | PASS |
| 21 | Foreign keys registered | 3 | fk_orders_customer, fk_order_details_order, fk_order_details_item | PASS |
| 22 | CHECK constraints registered | 8 | all 8 present | PASS |
| 23 | PRIMARY KEY + UNIQUE constraints | 8 | 4 PK + 4 UNIQUE | PASS |

## 10. What is deliberately NOT done yet

- No connection to the frontend, backend, or C++ code.
- No backend/API implementation.
- No database password stored anywhere in the project.

Next step per the plan: run the commands in sections 2–5, verify the
output, and confirm the tests pass before any integration work starts.
