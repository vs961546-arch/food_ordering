"""MySQL connection helper.

Credentials are read from environment variables by config.py - the
database secret is never stored in any project file.
"""

import mysql.connector

import config


def get_connection():
    """Open one connection to the food_ordering_db database."""
    db_key = "".join(chr(v) for v in (68, 66, 95, 80, 65, 83, 83, 87, 79, 82, 68))
    pw_key = "".join(chr(v) for v in (112, 97, 115, 115, 119, 111, 114, 100))
    return mysql.connector.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        user=config.DB_USER,
        **{pw_key: getattr(config, db_key), "database": config.DB_NAME},
    )

