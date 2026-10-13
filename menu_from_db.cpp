// ============================================================
// Food Ordering and Delivery System - C++ / MySQL integration
// File: menu_from_db.cpp
//
// READ-ONLY demo: loads the menu from the food_ordering_db
// database into a C++ dynamic array (std::vector), prints it,
// and prices a sample cart from the DATABASE prices - the idea
// of array_menu_food_items.cpp and food_ll_cart.cpp, but with
// live data from MySQL.
//
// Build (MinGW, from the cpp_db folder):
//   g++ -std=c++17 -o menu_from_db.exe menu_from_db.cpp ^
//       -I"C:\Program Files\MySQL\MySQL Server 8.0\include" ^
//       -L"C:\Program Files\MySQL\MySQL Server 8.0\lib" -lmysql
//
// Run (PowerShell, from the cpp_db folder):
//   $env:DB_PASSWORD = "your_mysql_password"
//   $env:PATH += ";C:\Program Files\MySQL\MySQL Server 8.0\lib"
//   .\menu_from_db.exe
// ============================================================

#include <mysql.h>

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

struct FoodItem {
    int item_id;
    std::string name;
    double price;
    bool is_available;
};

// Runs one SQL statement; prints the MySQL error and returns
// false if it fails.
bool exec(MYSQL* conn, const std::string& sql) {
    if (mysql_query(conn, sql.c_str()) != 0) {
        std::cerr << "SQL error: " << mysql_error(conn) << "\n";
        return false;
    }
    return true;
}

int main() {
    // Credentials come from environment variables - the same
    // place the Flask backend reads them from. No password is
    // stored in this file.
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

    std::cout << "Connected to MySQL " << mysql_get_server_info(conn)
              << ", database: food_ordering_db\n\n";

    // ---- 1. Load the menu into a C++ dynamic array ----
    if (!exec(conn, "SELECT item_id, name, price, is_available "
                    "FROM food_items ORDER BY name")) {
        mysql_close(conn);
        return 1;
    }

    MYSQL_RES* result = mysql_store_result(conn);
    if (result == nullptr) {
        std::cerr << "mysql_store_result failed: " << mysql_error(conn) << "\n";
        mysql_close(conn);
        return 1;
    }

    std::vector<FoodItem> menu;   // dynamic array of dishes
    MYSQL_ROW row;
    while ((row = mysql_fetch_row(result)) != nullptr) {
        FoodItem item;
        item.item_id = std::atoi(row[0]);
        item.name = row[1] ? row[1] : "";
        item.price = row[2] ? std::atof(row[2]) : 0.0;
        item.is_available = (row[3] && std::atoi(row[3]) != 0);
        menu.push_back(item);
    }
    mysql_free_result(result);

    // ---- 2. Print the menu (like array_menu_food_items.cpp,
    //         but the data comes from the database) ----
    std::cout << "Menu loaded from the database (" << menu.size() << " items):\n";
    std::cout << std::string(48, '-') << "\n";
    std::cout << std::left << std::setw(6) << "ID"
              << std::setw(16) << "Dish"
              << std::setw(10) << "Price"
              << "Available\n";
    std::cout << std::string(48, '-') << "\n";
    for (const FoodItem& item : menu) {
        std::cout << std::left << std::setw(6) << item.item_id
                  << std::setw(16) << item.name
                  << std::setw(10) << std::fixed << std::setprecision(2) << item.price
                  << (item.is_available ? "yes" : "no (sold out)") << "\n";
    }

    // ---- 3. Price a sample cart from the DATABASE prices ----
    //         (the idea of food_ll_cart.cpp, with live prices)
    struct CartLine { const char* dish; int quantity; };
    const CartLine cart[] = {{"pizza", 2}, {"coldrink", 1}};

    double total = 0.0;
    std::cout << "\nSample cart (prices read from the database):\n";
    for (const CartLine& line : cart) {
        const FoodItem* found = nullptr;
        for (const FoodItem& item : menu) {
            if (item.name == line.dish) {
                found = &item;
                break;
            }
        }
        if (found == nullptr) {
            std::cout << "  " << line.dish << " is not on the menu\n";
            continue;
        }
        const double line_total = found->price * line.quantity;
        total += line_total;
        std::cout << "  " << line.quantity << " x " << found->name
                  << " @ " << found->price << " = " << line_total << "\n";
    }
    std::cout << "  Cart total: " << total << "\n";

    mysql_close(conn);
    return 0;
}
