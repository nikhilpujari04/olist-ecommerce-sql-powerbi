"""
Load the Olist Brazilian E-Commerce dataset into PostgreSQL.

Usage:
    1. Install dependencies:
         pip install sqlalchemy psycopg2-binary pandas
    2. Create the database first (one-time):
         psql -U postgres -c "CREATE DATABASE olist_ecommerce;"
    3. Put all 7 CSV files in the same folder as this script (or update CSV_DIR below).
    4. Update the DB_CONFIG values with your local Postgres credentials.
    5. Run:
         python load_olist_to_postgres.py
"""

from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text

# ---------------------------------------------------------------------------
# 1. CONFIGURATION — edit these to match your local setup
# ---------------------------------------------------------------------------

DB_CONFIG = {
    "user": "postgres",
    "password": "YOUR_PASSWORD_HERE",   # <-- set this
    "host": "localhost",
    "port": 5432,
    "database": "olist_ecommerce",
}

CSV_DIR = Path(__file__).parent  # folder containing the 7 CSVs

CONN_STRING = (
    f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
    f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
)

# ---------------------------------------------------------------------------
# 2. SCHEMA — explicit DDL so types are correct (not pandas-inferred)
#    Order matters: parent tables before tables that reference them.
# ---------------------------------------------------------------------------

SCHEMA_SQL = """
DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS product_category_translation CASCADE;

CREATE TABLE customers (
    customer_id               VARCHAR(32) PRIMARY KEY,
    customer_unique_id        VARCHAR(32) NOT NULL,
    customer_zip_code_prefix  VARCHAR(10),
    customer_city             VARCHAR(100),
    customer_state            VARCHAR(2)
);

CREATE TABLE product_category_translation (
    product_category_name          VARCHAR(100) PRIMARY KEY,
    product_category_name_english  VARCHAR(100)
);

CREATE TABLE products (
    product_id                   VARCHAR(32) PRIMARY KEY,
    product_category_name        VARCHAR(100),
    product_name_lenght          NUMERIC,
    product_description_lenght   NUMERIC,
    product_photos_qty           NUMERIC,
    product_weight_g             NUMERIC,
    product_length_cm            NUMERIC,
    product_height_cm            NUMERIC,
    product_width_cm             NUMERIC,
    FOREIGN KEY (product_category_name)
        REFERENCES product_category_translation (product_category_name)
);

CREATE TABLE orders (
    order_id                        VARCHAR(32) PRIMARY KEY,
    customer_id                     VARCHAR(32) NOT NULL,
    order_status                    VARCHAR(20),
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

CREATE TABLE order_items (
    order_id             VARCHAR(32) NOT NULL,
    order_item_id        INTEGER NOT NULL,
    product_id            VARCHAR(32) NOT NULL,
    seller_id             VARCHAR(32) NOT NULL,
    shipping_limit_date   TIMESTAMP,
    price                 NUMERIC(10, 2),
    freight_value         NUMERIC(10, 2),
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES orders (order_id),
    FOREIGN KEY (product_id) REFERENCES products (product_id)
);

CREATE TABLE order_payments (
    order_id               VARCHAR(32) NOT NULL,
    payment_sequential     INTEGER NOT NULL,
    payment_type           VARCHAR(20),
    payment_installments   INTEGER,
    payment_value          NUMERIC(10, 2),
    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

CREATE TABLE order_reviews (
    review_id                 VARCHAR(32),
    order_id                  VARCHAR(32) NOT NULL,
    review_score              INTEGER,
    review_comment_title      TEXT,
    review_comment_message    TEXT,
    review_creation_date      TIMESTAMP,
    review_answer_timestamp   TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
);
"""

# ---------------------------------------------------------------------------
# 3. FILE -> TABLE MAPPING
#    (source CSV, target table, columns to parse as dates)
# ---------------------------------------------------------------------------

LOAD_PLAN = [
    ("olist_customers_dataset.csv", "customers", []),
    ("product_category_name_translation.csv", "product_category_translation", []),
    ("olist_products_dataset.csv", "products", []),
    (
        "olist_orders_dataset.csv",
        "orders",
        [
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
    ),
    ("olist_order_items_dataset.csv", "order_items", ["shipping_limit_date"]),
    ("olist_order_payments_dataset.csv", "order_payments", []),
    (
        "olist_order_reviews_dataset.csv",
        "order_reviews",
        ["review_creation_date", "review_answer_timestamp"],
    ),
]


def main() -> None:
    engine = create_engine(CONN_STRING)

    print("Creating schema...")
    with engine.begin() as conn:
        conn.execute(text(SCHEMA_SQL))
    print("Schema created.\n")

    for csv_name, table_name, date_cols in LOAD_PLAN:
        csv_path = CSV_DIR / csv_name
        if not csv_path.exists():
            print(f"  SKIPPED: {csv_name} not found in {CSV_DIR}")
            continue

        print(f"Loading {csv_name} -> {table_name} ...")
        df = pd.read_csv(csv_path, parse_dates=date_cols)

        # Known data quality issue: ~13 product_category_name values in the
        # products CSV don't exist in the translation CSV. Since products has
        # a FK to product_category_translation, backfill any missing category
        # names (with a NULL English translation) before loading products,
        # so the FK constraint doesn't reject those rows.
        if table_name == "products":
            existing = pd.read_sql(
                "SELECT product_category_name FROM product_category_translation",
                engine,
            )["product_category_name"].tolist()
            missing = sorted(
                set(df["product_category_name"].dropna()) - set(existing)
            )
            if missing:
                print(f"  -> backfilling {len(missing)} untranslated categories: {missing}")
                pd.DataFrame(
                    {"product_category_name": missing, "product_category_name_english": None}
                ).to_sql(
                    "product_category_translation",
                    engine,
                    if_exists="append",
                    index=False,
                )

        # order_reviews has some duplicate review_ids in the raw file; keep as-is,
        # duplicates are a known data quality issue worth discussing in your write-up.
        df.to_sql(table_name, engine, if_exists="append", index=False, method="multi", chunksize=5000)
        print(f"  -> {len(df):,} rows loaded")

    print("\nDone. Verifying row counts:")
    with engine.begin() as conn:
        for _, table_name, _ in LOAD_PLAN:
            count = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}")).scalar()
            print(f"  {table_name}: {count:,} rows")


if __name__ == "__main__":
    main()