"""Food Ordering and Delivery System - Flask backend API.

Serves the frontend (../frontend) and exposes a REST API over the
food_ordering_db MySQL database:

    GET  /                        frontend page (index.html)
    GET  /api/health              server + database name
    GET  /api/food                menu items (id, name, price, image,
                                  is_available)
    GET  /api/orders/<id>         one order + customer name + food names
    POST /api/customers           create a customer
    POST /api/orders              create an order (atomic transaction)
    PUT  /api/orders/<id>/status  change an order's status

POST /api/orders runs inside ONE database transaction: either every
row (customer, order, order_details, total) is written and COMMITted,
or any failure ROLLBACKs everything - a half-written order is impossible.

Run with:  .\run_backend.ps1   (prompts for the DB password securely)
"""

import os

import mysql.connector
from flask import Flask, jsonify, request

import config
import db

# Serve the frontend folder as the site root, so the page and the API
# share one origin (no CORS configuration needed).
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRONTEND_DIR = os.path.join(BASE_DIR, "frontend")

app = Flask(__name__, static_folder=FRONTEND_DIR, static_url_path="")


# ---------------------------------------------------------------- helpers
def money(value):
    """Convert a DECIMAL column value to a JSON-friendly float."""
    return float(value)


def _opt(value):
    """Normalize an optional string field: blank -> None (NULL)."""
    text = str(value or "").strip()
    return text or None


# ------------------------------------------------------------------ pages
@app.get("/")
def index():
    return app.send_static_file("index.html")


# -------------------------------------------------------------------- API
@app.get("/api/health")
def health():
    return jsonify({"status": "ok", "database": config.DB_NAME})


# Local image for each dish (files in frontend/images/).
# Keyed by the food_items.name stored in the database.
IMAGES = {
    "pizza": "pizza.svg",
    "burger": "burger.svg",
    "dosa": "dosa.svg",
    "biriyani": "biriyani.svg",
    "chips": "chips.svg",
    "coldrink": "coldrink.svg",
    "cold coffee": "cold_coffee.svg",
    "french fries": "french_fries.svg",
    "dal makhni": "dal_makhni.svg",
    "patties": "patties.svg",
    "popcorn": "popcorn.svg",
}


@app.get("/api/food")
def list_food():
    """All menu items. The frontend hides items with is_available = 0."""
    conn = db.get_connection()
    try:
        with conn.cursor(dictionary=True) as cur:
            cur.execute(
                "SELECT item_id, name, price, is_available "
                "FROM food_items ORDER BY name"
            )
            rows = cur.fetchall()
    finally:
        conn.close()
    return jsonify([
        {
            "item_id": r["item_id"],
            "name": r["name"],
            "price": money(r["price"]),
            "is_available": bool(r["is_available"]),
            "image": "/images/" + IMAGES.get(r["name"], "placeholder.svg"),
        }
        for r in rows
    ])


@app.post("/api/customers")
def create_customer():
    """Create a customer. phone / email / address are optional."""
    data = request.get_json(silent=True) or {}
    name = str(data.get("name") or "").strip()
    if not name:
        return jsonify({"error": "name is required"}), 400

    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO customers (name, phone, email, address) "
                "VALUES (%s, %s, %s, %s)",
                (name, _opt(data.get("phone")), _opt(data.get("email")),
                 _opt(data.get("address"))),
            )
            customer_id = cur.lastrowid
        conn.commit()
    except mysql.connector.IntegrityError as err:
        conn.rollback()
        # ERROR 1062: the UNIQUE phone or email already exists
        return jsonify({"error": f"duplicate contact detail: {err}"}), 400
    except mysql.connector.Error as err:
        conn.rollback()
        return jsonify({"error": f"database error: {err}"}), 500
    finally:
        conn.close()
    return jsonify({"customer_id": customer_id, "name": name}), 201


@app.post("/api/orders")
def create_order():
    """Create an order.

    Request JSON:
        {
          "customer": {"name": "...", "phone": "...", "email": "...",
                       "address": "..."}        (or "customer_id": 5)
          "items": [{"item_id": 1, "quantity": 2}, ...]
        }

    The whole order is written in a single transaction (COMMIT on
    success, ROLLBACK on any failure). The current menu price is
    copied into order_details.unit_price at purchase time, so later
    menu-price changes never rewrite order history.
    """
    data = request.get_json(silent=True) or {}
    items = data.get("items")
    if not isinstance(items, list) or not items:
        return jsonify({"error": "items must be a non-empty list"}), 400

    # ---- validate everything BEFORE touching the database ----
    wanted = []  # [(item_id, quantity), ...]
    for entry in items:
        if not isinstance(entry, dict):
            return jsonify({"error": "each item must be an object"}), 400
        try:
            item_id = int(entry.get("item_id"))
            quantity = int(entry.get("quantity"))
        except (TypeError, ValueError):
            return jsonify({"error": "item_id and quantity must be integers"}), 400
        if quantity <= 0:
            return jsonify({"error": f"quantity for item {item_id} must be positive"}), 400
        if item_id in [i for i, _ in wanted]:
            return jsonify({"error": f"item {item_id} appears twice - "
                                     f"increase its quantity instead"}), 400
        wanted.append((item_id, quantity))

    customer = data.get("customer") or {}
    create_customer_row = customer.get("customer_id") is None
    if create_customer_row:
        name = str(customer.get("name") or "").strip()
        if not name:
            return jsonify({"error": "customer.name is required when "
                                     "customer_id is not given"}), 400
    else:
        try:
            customer_id = int(customer.get("customer_id"))
        except (TypeError, ValueError):
            return jsonify({"error": "customer.customer_id must be an integer"}), 400
        name = None

    # ---- write the whole order in ONE transaction ----
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            conn.start_transaction()

            if create_customer_row:
                cur.execute(
                    "INSERT INTO customers (name, phone, email, address) "
                    "VALUES (%s, %s, %s, %s)",
                    (name, _opt(customer.get("phone")),
                     _opt(customer.get("email")),
                     _opt(customer.get("address"))),
                )
                customer_id = cur.lastrowid

            cur.execute("INSERT INTO orders (customer_id) VALUES (%s)",
                        (customer_id,))
            order_id = cur.lastrowid

            # Current menu prices for the requested items
            placeholders = ", ".join(["%s"] * len(wanted))
            cur.execute(
                f"SELECT item_id, price FROM food_items "
                f"WHERE item_id IN ({placeholders})",
                [i for i, _ in wanted],
            )
            prices = {item_id: money(price) for item_id, price in cur.fetchall()}

            for item_id, quantity in wanted:
                if item_id not in prices:
                    raise LookupError(f"item_id {item_id} does not exist")
                unit_price = prices[item_id]
                subtotal = round(unit_price * quantity, 2)
                cur.execute(
                    "INSERT INTO order_details (order_id, item_id, quantity, "
                    "unit_price, subtotal) VALUES (%s, %s, %s, %s, %s)",
                    (order_id, item_id, quantity, unit_price, subtotal),
                )

            # Store the calculated grand total on the order
            cur.execute(
                "UPDATE orders o "
                "JOIN (SELECT order_id, SUM(subtotal) AS t FROM order_details "
                "      GROUP BY order_id) d ON d.order_id = o.order_id "
                "SET o.total_amount = d.t "
                "WHERE o.order_id = %s",
                (order_id,),
            )
            cur.execute("SELECT total_amount FROM orders WHERE order_id = %s",
                        (order_id,))
            total = money(cur.fetchone()[0])

        conn.commit()  # permanent: customer + order + details + total
    except LookupError as err:
        conn.rollback()  # undo everything written above
        return jsonify({"error": str(err)}), 400
    except mysql.connector.IntegrityError as err:
        conn.rollback()
        # e.g. ERROR 1452 (customer_id does not exist), ERROR 3819 (CHECK)
        return jsonify({"error": f"database rejected the order: {err}"}), 400
    except mysql.connector.Error as err:
        conn.rollback()
        return jsonify({"error": f"database error: {err}"}), 500
    finally:
        conn.close()

    return jsonify({"order_id": order_id, "customer_id": customer_id,
                    "status": "placed", "total_amount": total}), 201


@app.get("/api/orders/<int:order_id>")
def get_order(order_id):
    """One order with the customer's name and each dish's name."""
    conn = db.get_connection()
    try:
        with conn.cursor(dictionary=True) as cur:
            cur.execute(
                "SELECT o.order_id, o.order_date, o.status, o.total_amount, "
                "       c.customer_id, c.name AS customer_name, c.phone, c.address "
                "FROM orders o "
                "JOIN customers c ON c.customer_id = o.customer_id "
                "WHERE o.order_id = %s",
                (order_id,),
            )
            order = cur.fetchone()
            if order is None:
                return jsonify({"error": f"order {order_id} not found"}), 404

            cur.execute(
                "SELECT f.name AS food_name, od.quantity, od.unit_price, od.subtotal "
                "FROM order_details od "
                "JOIN food_items f ON f.item_id = od.item_id "
                "WHERE od.order_id = %s "
                "ORDER BY od.order_detail_id",
                (order_id,),
            )
            items = cur.fetchall()
    finally:
        conn.close()

    order["order_date"] = order["order_date"].isoformat(sep=" ")
    order["total_amount"] = money(order["total_amount"])
    for item in items:
        item["unit_price"] = money(item["unit_price"])
        item["subtotal"] = money(item["subtotal"])
    order["items"] = items
    return jsonify(order)


@app.put("/api/orders/<int:order_id>/status")
def update_order_status(order_id):
    """Change an order's status. The database CHECK constraint only
    allows: placed, preparing, out_for_delivery, delivered, cancelled."""
    data = request.get_json(silent=True) or {}
    status = str(data.get("status") or "").strip()
    allowed = ("placed", "preparing", "out_for_delivery", "delivered", "cancelled")
    if status not in allowed:
        return jsonify({"error": f"status must be one of: {', '.join(allowed)}"}), 400

    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE orders SET status = %s WHERE order_id = %s",
                        (status, order_id))
            if cur.rowcount == 0:
                return jsonify({"error": f"order {order_id} not found"}), 404
        conn.commit()
    except mysql.connector.Error as err:
        conn.rollback()
        return jsonify({"error": f"database error: {err}"}), 400
    finally:
        conn.close()
    return jsonify({"order_id": order_id, "status": status})


if __name__ == "__main__":
    # Development server (FLASK_DEBUG=0 disables the auto-reloader).
    app.run(host="127.0.0.1", port=5000,
            debug=os.environ.get("FLASK_DEBUG", "1") == "1")
