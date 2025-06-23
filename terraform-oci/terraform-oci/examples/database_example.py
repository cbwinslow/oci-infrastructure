#!/usr/bin/env python3

import os
import cx_Oracle
from contextlib import contextmanager
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class DatabaseConfig:
    USERNAME = "ADMIN"
    PASSWORD = os.getenv("DB_PASSWORD")
    DSN = "ORCL_high"
    TNS_ADMIN = os.getenv("TNS_ADMIN", os.path.expanduser("~/.oracle/wallet/ORCL"))

class DatabasePool:
    _pool = None

    @classmethod
    def initialize(cls, min_connections=2, max_connections=5):
        if cls._pool is None:
            cls._pool = cx_Oracle.SessionPool(
                user=DatabaseConfig.USERNAME,
                password=DatabaseConfig.PASSWORD,
                dsn=DatabaseConfig.DSN,
                min=min_connections,
                max=max_connections,
                increment=1,
                encoding="UTF-8",
                config_dir=DatabaseConfig.TNS_ADMIN
            )
        return cls._pool

    @classmethod
    def get_pool(cls):
        if cls._pool is None:
            cls.initialize()
        return cls._pool

    @classmethod
    def close(cls):
        if cls._pool is not None:
            cls._pool.close()
            cls._pool = None

@contextmanager
def get_connection():
    """Context manager for database connections"""
    connection = DatabasePool.get_pool().acquire()
    try:
        yield connection
    finally:
        DatabasePool.get_pool().release(connection)

def create_sample_tables():
    """Create sample tables for demonstration"""
    with get_connection() as connection:
        cursor = connection.cursor()
        
        # Create products table
        cursor.execute("""
            CREATE TABLE products (
                product_id NUMBER GENERATED ALWAYS AS IDENTITY,
                name VARCHAR2(100) NOT NULL,
                price NUMBER(10,2) NOT NULL,
                created_date DATE DEFAULT SYSDATE,
                CONSTRAINT products_pk PRIMARY KEY (product_id)
            )
        """)
        
        # Create orders table
        cursor.execute("""
            CREATE TABLE orders (
                order_id NUMBER GENERATED ALWAYS AS IDENTITY,
                product_id NUMBER NOT NULL,
                quantity NUMBER(10) NOT NULL,
                total_price NUMBER(10,2) NOT NULL,
                order_date DATE DEFAULT SYSDATE,
                CONSTRAINT orders_pk PRIMARY KEY (order_id),
                CONSTRAINT orders_products_fk FOREIGN KEY (product_id)
                    REFERENCES products(product_id)
            )
        """)
        
        print("Sample tables created successfully")

def insert_sample_data():
    """Insert sample data into the tables"""
    products = [
        ("Laptop", 999.99),
        ("Mouse", 24.99),
        ("Keyboard", 59.99),
        ("Monitor", 299.99)
    ]
    
    with get_connection() as connection:
        cursor = connection.cursor()
        
        # Insert products
        cursor.executemany(
            "INSERT INTO products (name, price) VALUES (:1, :2)",
            products
        )
        
        # Get product IDs for orders
        cursor.execute("SELECT product_id FROM products")
        product_ids = [row[0] for row in cursor.fetchall()]
        
        # Insert sample orders
        orders = [
            (product_ids[0], 2, 1999.98),
            (product_ids[1], 5, 124.95),
            (product_ids[2], 3, 179.97),
            (product_ids[3], 1, 299.99)
        ]
        
        cursor.executemany(
            "INSERT INTO orders (product_id, quantity, total_price) VALUES (:1, :2, :3)",
            orders
        )
        
        connection.commit()
        print("Sample data inserted successfully")

def query_data():
    """Query and display sample data"""
    with get_connection() as connection:
        cursor = connection.cursor()
        
        # Query orders with product details
        cursor.execute("""
            SELECT 
                o.order_id,
                p.name as product_name,
                o.quantity,
                o.total_price,
                o.order_date
            FROM orders o
            JOIN products p ON o.product_id = p.product_id
            ORDER BY o.order_date DESC
        """)
        
        # Print results
        print("\nOrder Details:")
        print("-" * 70)
        print(f"{'Order ID':<10} {'Product':<20} {'Quantity':<10} {'Total Price':<15} {'Order Date':<15}")
        print("-" * 70)
        
        for row in cursor:
            print(f"{row[0]:<10} {row[1]:<20} {row[2]:<10} ${row[3]:<14.2f} {row[4]:%Y-%m-%d}")

def cleanup_sample_data():
    """Clean up sample tables"""
    with get_connection() as connection:
        cursor = connection.cursor()
        
        # Drop tables in correct order due to foreign key constraints
        try:
            cursor.execute("DROP TABLE orders")
            cursor.execute("DROP TABLE products")
            print("Sample tables cleaned up successfully")
        except cx_Oracle.DatabaseError as e:
            print(f"Error cleaning up tables: {e}")

def main():
    """Main demonstration function"""
    try:
        print("Initializing database connection pool...")
        DatabasePool.initialize()
        
        print("\nCreating sample tables...")
        create_sample_tables()
        
        print("\nInserting sample data...")
        insert_sample_data()
        
        print("\nQuerying data...")
        query_data()
        
        print("\nCleaning up...")
        cleanup_sample_data()
        
    except cx_Oracle.DatabaseError as e:
        print(f"Database error occurred: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        DatabasePool.close()
        print("\nDemo completed!")

if __name__ == "__main__":
    main()

