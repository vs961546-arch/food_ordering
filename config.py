"""Database configuration for the Food Ordering and Delivery System.

Credentials come from ENVIRONMENT VARIABLES ONLY - no password is
stored in this file, and nothing here is ever sent to the frontend.

Required:
    DB_PASSWORD   MySQL password for DB_USER
Optional (defaults below):
    DB_HOST, DB_PORT, DB_USER, DB_NAME
"""

import os

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_USER = os.environ.get("DB_USER", "root")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
DB_NAME = os.environ.get("DB_NAME", "food_ordering_db")
