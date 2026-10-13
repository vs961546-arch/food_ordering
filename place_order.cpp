// ============================================================
// Food Ordering and Delivery System - C++ / MySQL integration
// File: place_order.cpp
//
// WRITE demo: creates one order in food_ordering_db inside a
// single transaction (COMMIT on success, ROLLBACK on any
// failure) - the same rules the Flask API follows.
//
// Usage:  place_order.exe [customer_name]
//         (default customer name: "C++ Customer")
//
// Build (MinGW, from the cpp_db folder):
//   g++ -std=c++17 -o place_order.exe place_order.cpp ^
//       -I"C:\Program Files\MySQL\MySQL Server 8.0\include" ^
//       -L"C:\Program Files\MySQL\MySQL Server 8.0\lib" -lmysql
//
// Run (PowerShell, from the cpp_db folder):
//   $env:DB_PASSWORD = "your_mysql_password"
//   $env:PATH += ";C:\Program Files\MySQL\MySQL Server 8.0\lib"
//   .\place_order.exe "Ravi Kumar"
// ============================================================

#include <mysql.h>

#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

bool exec(MYSQL* conn, const std::string& sql) {
    if (mysql_query(conn, sql.c_str()) != 0) {
        std::cerr << "SQL error: " << mysql_error(conn) << "\n";
        return false;
    }
    return true;
}

// Escapes a string for safe inclusion in a SQL statement.
std::string escape(MYSQL* conn, const std::string& value) {
    std::vector<char> buffer(value.size() * 2 + 1);
    const unsigned long length = mysql_real_escape_string(
        conn, buffer.data(), value.c_str(),
        static_cast<unsigned long>(value.size()));
    return std::string(buffer.data(), length);
}

// Rolls the transaction back and closes the connection.
int fail(MYSQL* conn) {
    exec(conn, "ROLLBACK");
    std::cerr << "Transaction rolled back - nothing was saved.\n";
    mysql_close(conn);
    return 1;
}

int main(int argc, char* argv[]) {
    const std::string customer_name = (argc > 1) ? argv[1] : "C++ Customer";

    // Credentials from environment variables (never in code).
    const char* host = std::getenv("DB_HOST");
    const char* user = std::getenv("DB_USER");
    const char* pass = std::getenv("DB_PASSWORD");
    const char* dbname = std::getenv("DB_NAME");

    MYSQL* conn = mysql_init(nullptr);
    if (conn == nullptr) {
        std::cerr << "mysql_init failed\n";
        return 1;
    }

    if (mysql_real_connect(conn,
                           host ? host : "localhost",
                           user ? user : "root",
                           pass ? pass : "",
                           dbname ? dbname : "food_ordering_db",
                           0, nullptr, 0) == nullptr) {
        std::cerr << "Connection failed: " << mysql_error(conn) << "\n";
        mysql_close(conn);
        return 1;
    }

    // The order: 2 x pizza (item_id 1) + 1 x coldrink (item_id 6).
    // Prices are READ from the database, never hardcoded.
    struct OrderLine { int item_id; int quantity; };
    const OrderLine lines[] = {{1, 2}, {6, 1}};

    if (!exec(conn, "START TRANSACTION")) {
        mysql_close(conn);
        return 1;
    }

    // 1. Create the customer.
    const std::string sql_customer =
        "INSERT INTO customers (name) VALUES ('" +
        escape(conn, customer_name) + "')";
    if (!exec(conn, sql_customer)) return fail(conn);
    const unsigned long long customer_id = mysql_insert_id(conn);

    // 2. Create the order header.
    const std::string sql_order =
        "INSERT INTO orders (customer_id) VALUES (" +
        std::to_string(customer_id) + ")";
    if (!exec(conn, sql_order)) return fail(conn);
    const unsigned long long order_id = mysql_insert_id(conn);

    // 3. Add line items, looking up the CURRENT price of each.
    double total = 0.0;
    for (const OrderLine& line : lines) {
        const std::string sql_price =
            "SELECT price FROM food_items WHERE item_id = " +
            std::to_string(line.item_id);
        if (!exec(conn, sql_price)) return fail(conn);

        MYSQL_RES* result = mysql_store_result(conn);
        if (result == nullptr || mysql_num_rows(result) == 0) {
            std::cerr << "item_id " << line.item_id << " does not exist\n";
            if (result) mysql_free_result(result);
            return fail(conn);
        }
        MYSQL_ROW row = mysql_fetch_row(result);
        const double unit_price = std::atof(row[0]);
        const double subtotal = unit_price * line.quantity;
        mysql_free_result(result);

        const std::string sql_detail =
            "INSERT INTO order_details (order_id, item_id, quantity, "
            "unit_price, subtotal) VALUES (" +
            std::to_string(order_id) + ", " +
            std::to_string(line.item_id) + ", " +
            std::to_string(line.quantity) + ", " +
            std::to_string(unit_price) + ", " +
            std::to_string(subtotal) + ")";
        if (!exec(conn, sql_detail)) return fail(conn);
        total += subtotal;
    }

    // 4. Store the calculated grand total on the order.
    const std::string sql_total =
        "UPDATE orders o "
        "JOIN (SELECT order_id, SUM(subtotal) AS t FROM order_details "
        "      GROUP BY order_id) d ON d.order_id = o.order_id "
        "SET o.total_amount = d.t WHERE o.order_id = " +
        std::to_string(order_id);
    if (!exec(conn, sql_total)) return fail(conn);

    // 5. Commit - everything becomes permanent at once.
    if (!exec(conn, "COMMIT")) {
        mysql_close(conn);
        return 1;
    }

    std::cout << "Order created by C++ and committed to the database:\n"
              << "  order_id:    " << order_id << "\n"
              << "  customer_id: " << customer_id
              << " (" << customer_name << ")\n"
              << "  total:       " << total << "\n";

    mysql_close(conn);
    return 0;
}
