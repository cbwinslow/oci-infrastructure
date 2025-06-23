# OCI Infrastructure and Database Access Guide

This guide explains how to set up and access an Oracle Cloud Infrastructure (OCI) environment with an Autonomous Database, compute instance, and all necessary networking components.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Infrastructure Components](#infrastructure-components)
- [Initial Setup](#initial-setup)
- [Instance Configuration](#instance-configuration)
- [Database Access](#database-access)
  - [Python Examples](#python-examples)
  - [TypeScript Examples](#typescript-examples)
  - [Other Methods](#other-methods)
- [Security Considerations](#security-considerations)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Infrastructure Components

This configuration creates:

1. **Database Resources**:
   - Autonomous Database (Free Tier)
   - Database user with proper permissions
   - Wallet configuration
   - Connection strings and URLs

2. **Compute Instance**:
   - Ubuntu-based VM (Free Tier eligible)
   - Public IP address
   - Oracle Instant Client pre-installed
   - Development tools (Python, Node.js)

3. **Network Resources**:
   - VCN with internet gateway
   - Public subnet for the instance
   - Security lists for both database and instance
   - Network security groups for database access

4. **Storage**:
   - 50GB block volume
   - Automatic attachment to instance
   - Paravirtualized for better performance

## Prerequisites

1. OCI CLI configured
2. Terraform installed
3. SSH key pair for instance access
4. Oracle Cloud account with Free Tier access

## Initial Setup

1. Clone this repository:
```bash
git clone <repository-url>
cd terraform-oci
```

2. Create terraform.tfvars:
```hcl
region           = "your-region"
compartment_id   = "your-compartment-ocid"
tenancy_ocid     = "your-tenancy-ocid"
user_ocid        = "your-user-ocid"
fingerprint      = "your-api-key-fingerprint"
private_key_path = "~/.oci/oci_api_key.pem"
ssh_public_key   = "your-ssh-public-key"
instance_image_id = "ocid-of-ubuntu-image"

db_name           = "ORCL"
db_admin_password = "your-secure-password"
db_user_name      = "app_user"
db_user_password  = "your-app-user-password"
wallet_password   = "your-wallet-password"
```

3. Initialize and apply Terraform:
```bash
terraform init
terraform plan
terraform apply
```

4. Set up the instance:
```bash
./scripts/setup_instance.sh $(terraform output -raw instance_public_ip)
```

## Instance Configuration

The compute instance is configured with:
- Public IP for easy access
- Oracle Instant Client
- Python with cx_Oracle
- Node.js with oracledb
- Proper wallet configuration
- Environment variables set

### Accessing the Instance

```bash
ssh ubuntu@$(terraform output -raw instance_public_ip)
```

### Environment Variables
```bash
export TNS_ADMIN=$HOME/.oracle/wallet/ORCL
export ORACLE_HOME=/usr/lib/oracle/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
```

## Database Access

### Python Examples

1. Basic Connection:
```python
import cx_Oracle
import os
from dotenv import load_dotenv

load_dotenv()

connection = cx_Oracle.connect(
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD'),
    dsn='ORCL_high',
    config_dir=os.getenv('TNS_ADMIN')
)

with connection.cursor() as cursor:
    cursor.execute('SELECT SYSDATE FROM DUAL')
    result = cursor.fetchone()
    print(f'Database time: {result[0]}')
```

2. CRUD Operations:
```python
from contextlib import contextmanager

@contextmanager
def get_connection():
    connection = None
    try:
        connection = cx_Oracle.connect(
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            dsn='ORCL_high',
            config_dir=os.getenv('TNS_ADMIN')
        )
        yield connection
    finally:
        if connection:
            connection.close()

def create_user(name: str, email: str):
    with get_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            'INSERT INTO users (name, email) VALUES (:1, :2)',
            [name, email]
        )
        connection.commit()
        return cursor.lastrowid
```

### TypeScript Examples

1. Basic Connection:
```typescript
import oracledb from 'oracledb';
import dotenv from 'dotenv';

dotenv.config();

async function connectToDatabase() {
    let connection;
    try {
        connection = await oracledb.getConnection({
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
            connectString: 'ORCL_high',
            configDir: process.env.TNS_ADMIN
        });

        const result = await connection.execute('SELECT SYSDATE FROM DUAL');
        console.log('Database time:', result.rows?.[0]);
    } finally {
        if (connection) {
            await connection.close();
        }
    }
}
```

2. Connection Pool:
```typescript
import oracledb, { Connection, Pool } from 'oracledb';

class DatabasePool {
    private static pool: Pool | null = null;

    static async initialize(): Promise<Pool> {
        if (!this.pool) {
            this.pool = await oracledb.createPool({
                user: process.env.DB_USER,
                password: process.env.DB_PASSWORD,
                connectString: 'ORCL_high',
                configDir: process.env.TNS_ADMIN,
                poolMin: 2,
                poolMax: 5,
                poolIncrement: 1
            });
        }
        return this.pool;
    }

    static async getConnection(): Promise<Connection> {
        if (!this.pool) {
            await this.initialize();
        }
        return await this.pool!.getConnection();
    }

    static async close(): Promise<void> {
        if (this.pool) {
            await this.pool.close(0);
            this.pool = null;
        }
    }
}

// Usage example
async function createUser(name: string, email: string): Promise<number> {
    const connection = await DatabasePool.getConnection();
    try {
        const result = await connection.execute(
            'INSERT INTO users (name, email) VALUES (:1, :2) RETURNING id INTO :3',
            [name, email, { type: oracledb.NUMBER, dir: oracledb.BIND_OUT }]
        );
        await connection.commit();
        return result.outBinds[0][0];
    } finally {
        await connection.close();
    }
}
```

3. Transaction Example:
```typescript
import { Connection } from 'oracledb';

async function transferMoney(
    fromAccount: string,
    toAccount: string,
    amount: number
): Promise<void> {
    const connection = await DatabasePool.getConnection();
    try {
        await connection.execute('BEGIN');

        // Debit from account
        await connection.execute(
            'UPDATE accounts SET balance = balance - :1 WHERE account_id = :2',
            [amount, fromAccount]
        );

        // Credit to account
        await connection.execute(
            'UPDATE accounts SET balance = balance + :1 WHERE account_id = :2',
            [amount, toAccount]
        );

        await connection.execute('COMMIT');
    } catch (error) {
        await connection.execute('ROLLBACK');
        throw error;
    } finally {
        await connection.close();
    }
}
```

### Other Methods

1. SQLPlus:
```bash
sqlplus app_user@ORCL_high
```

2. JDBC:
```java
String url = "jdbc:oracle:thin:@ORCL_high?TNS_ADMIN=/home/ubuntu/.oracle/wallet/ORCL";
Connection conn = DriverManager.getConnection(url, "app_user", "your_password");
```

## Security Considerations

1. Wallet Management:
   - Keep wallet files secure
   - Use proper file permissions (600)
   - Never commit wallet files to version control

2. Password Handling:
   - Use environment variables
   - Never hardcode passwords
   - Rotate passwords regularly

3. Network Security:
   - Restrict IP ranges in security lists
   - Use NSGs for fine-grained control
   - Keep ports closed unless needed

## Best Practices

1. Connection Management:
   - Use connection pooling
   - Close connections properly
   - Handle errors appropriately

2. Error Handling:
   - Implement proper try-catch blocks
   - Log errors appropriately
   - Use transactions where needed

3. Resource Management:
   - Monitor instance metrics
   - Watch database performance
   - Clean up unused resources

## Troubleshooting

1. Connection Issues:
   - Check wallet configuration
   - Verify TNS_ADMIN setting
   - Confirm security list rules

2. Performance Issues:
   - Check connection pooling
   - Monitor resource usage
   - Review query execution plans

3. Instance Access:
   - Verify SSH key configuration
   - Check security list rules
   - Confirm instance state

This guide explains how to access the Oracle Autonomous Database programmatically, with a focus on Python integration.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Environment Configuration](#environment-configuration)
- [Python Examples](#python-examples)
  - [Basic Connection](#basic-connection)
  - [Data Operations](#data-operations)
  - [Error Handling](#error-handling)
  - [Connection Pooling](#connection-pooling)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Prerequisites

1. Oracle Instant Client (for Linux):
```bash
# Add Oracle's repository
sudo bash -c 'echo "deb [arch=$(dpkg --print-architecture)] https://download.oracle.com/linux/oracle/deb/ stable main" > /etc/apt/sources.list.d/oracle-database.list'
sudo apt-get update
sudo apt-get install oracle-instantclient-basic oracle-instantclient-sqlplus

# Set environment variables
echo 'export LD_LIBRARY_PATH=/usr/lib/oracle/client64/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
echo 'export ORACLE_HOME=/usr/lib/oracle/client64' >> ~/.bashrc
source ~/.bashrc
```

2. Python packages:
```bash
pip install cx-Oracle python-dotenv
```

## Initial Setup

1. Set up the wallet:
```bash
# Run the setup script
./setup_db_connection.sh
```

2. Configure environment variables:
```bash
export TNS_ADMIN=$HOME/.oracle/wallet/ORCL
export ORACLE_HOME=/usr/lib/oracle/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
```

## TypeScript Examples

### Prerequisites

1. Install Node.js and npm
2. Install TypeScript globally:
```bash
npm install -g typescript
```

### Setup TypeScript Project

1. Install dependencies:
```bash
cd examples/typescript
npm install
```

2. Configure environment:
```bash
cp .env.template .env
# Edit .env with your credentials
```

3. Build and run:
```bash
npm run build
npm start
```

Or run directly with ts-node:
```bash
npm run dev
```

### TypeScript Example Code

```typescript
// Database connection setup
import oracledb from 'oracledb';

interface DatabaseConfig {
  user: string;
  password: string;
  connectString: string;
}

async function getConnection(config: DatabaseConfig) {
  try {
    const connection = await oracledb.getConnection({
      user: config.user,
      password: config.password,
      connectString: config.connectString
    });
    console.log('Connected to database');
    return connection;
  } catch (error) {
    console.error('Error connecting to database:', error);
    throw error;
  }
}

// Example query with parameters
async function getOrderById(orderId: number) {
  const connection = await getConnection(dbConfig);
  try {
    const result = await connection.execute(
      `SELECT * FROM orders WHERE order_id = :id`,
      { id: orderId },
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );
    return result.rows?.[0] || null;
  } finally {
    await connection.close();
  }
}

// Example transaction
async function createOrderWithItems(order: Order, items: OrderItem[]) {
  const connection = await getConnection(dbConfig);
  try {
    await connection.execute('BEGIN');

    // Insert order
    const orderResult = await connection.execute(
      `INSERT INTO orders (customer_id, order_date) 
       VALUES (:customer_id, SYSDATE) 
       RETURNING order_id INTO :order_id`,
      {
        customer_id: order.customerId,
        order_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
      }
    );

    const orderId = orderResult.outBinds.order_id[0];

    // Insert items
    for (const item of items) {
      await connection.execute(
        `INSERT INTO order_items (order_id, product_id, quantity) 
         VALUES (:order_id, :product_id, :quantity)`,
        {
          order_id: orderId,
          product_id: item.productId,
          quantity: item.quantity
        }
      );
    }

    await connection.execute('COMMIT');
    return orderId;
  } catch (error) {
    await connection.execute('ROLLBACK');
    throw error;
  } finally {
    await connection.close();
  }
}
```

## Python Examples

### Basic Connection

```python
import cx_Oracle
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database credentials
username = "ADMIN"
password = os.getenv("DB_PASSWORD")
dsn = "ORCL_high"  # Use high, medium, or low service

def get_connection():
    """Create and return a database connection"""
    try:
        connection = cx_Oracle.connect(
            user=username,
            password=password,
            dsn=dsn,
            config_dir=os.getenv("TNS_ADMIN")
        )
        print("Successfully connected to Oracle Database")
        return connection
    except cx_Oracle.Error as error:
        print(f"Error connecting to the database: {error}")
        raise

# Example usage
try:
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute("SELECT SYSDATE FROM DUAL")
    result = cursor.fetchone()
    print(f"Current database time: {result[0]}")
finally:
    if 'cursor' in locals():
        cursor.close()
    if 'connection' in locals():
        connection.close()
```

### Data Operations

```python
import cx_Oracle
from contextlib import contextmanager

@contextmanager
def database_connection():
    """Context manager for database connections"""
    connection = None
    try:
        connection = cx_Oracle.connect(
            user="ADMIN",
            password=os.getenv("DB_PASSWORD"),
            dsn="ORCL_high",
            config_dir=os.getenv("TNS_ADMIN")
        )
        yield connection
    finally:
        if connection:
            connection.close()

# Example: Create a table
def create_example_table():
    with database_connection() as connection:
        cursor = connection.cursor()
        cursor.execute("""
            CREATE TABLE customers (
                customer_id NUMBER GENERATED ALWAYS AS IDENTITY,
                name VARCHAR2(100),
                email VARCHAR2(255),
                created_date DATE DEFAULT SYSDATE,
                CONSTRAINT customers_pk PRIMARY KEY (customer_id)
            )
        """)
        print("Table created successfully")

# Example: Insert data
def insert_customer(name, email):
    with database_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO customers (name, email) VALUES (:1, :2)",
            (name, email)
        )
        connection.commit()
        return cursor.lastrowid

# Example: Query data
def get_customer(customer_id):
    with database_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT * FROM customers WHERE customer_id = :1",
            [customer_id]
        )
        columns = [col[0] for col in cursor.description]
        result = cursor.fetchone()
        return dict(zip(columns, result)) if result else None

# Example: Batch insert
def batch_insert_customers(customers):
    with database_connection() as connection:
        cursor = connection.cursor()
        cursor.executemany(
            "INSERT INTO customers (name, email) VALUES (:1, :2)",
            customers
        )
        connection.commit()
```

### Error Handling

```python
import cx_Oracle

class DatabaseError(Exception):
    """Custom exception for database errors"""
    pass

def safe_execute(query, params=None):
    """Execute a query with proper error handling"""
    with database_connection() as connection:
        try:
            cursor = connection.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            
            if query.strip().upper().startswith('SELECT'):
                columns = [col[0] for col in cursor.description]
                results = [dict(zip(columns, row)) for row in cursor.fetchall()]
                return results
            else:
                connection.commit()
                return cursor.rowcount
        except cx_Oracle.DatabaseError as e:
            error, = e.args
            raise DatabaseError(f"Oracle Error: {error.code} - {error.message}")
```

### Connection Pooling

```python
import cx_Oracle
from contextlib import contextmanager

class DatabasePool:
    _pool = None

    @classmethod
    def initialize(cls, min=2, max=5):
        """Initialize the connection pool"""
        try:
            cls._pool = cx_Oracle.SessionPool(
                user="ADMIN",
                password=os.getenv("DB_PASSWORD"),
                dsn="ORCL_high",
                min=min,
                max=max,
                increment=1,
                encoding="UTF-8",
                config_dir=os.getenv("TNS_ADMIN")
            )
            print(f"Connection pool created with {min} to {max} connections")
        except cx_Oracle.Error as error:
            print(f"Error creating connection pool: {error}")
            raise

    @classmethod
    @contextmanager
    def acquire(cls):
        """Acquire a connection from the pool"""
        if not cls._pool:
            cls.initialize()
        
        connection = cls._pool.acquire()
        try:
            yield connection
        finally:
            cls._pool.release(connection)

# Example usage with connection pool
def example_pool_usage():
    with DatabasePool.acquire() as connection:
        cursor = connection.cursor()
        cursor.execute("SELECT * FROM customers")
        results = cursor.fetchall()
        return results
```

## Best Practices

1. Always use connection pooling for applications
2. Use parameterized queries to prevent SQL injection
3. Handle database connections with context managers
4. Implement proper error handling
5. Close cursors and connections properly
6. Use connection pools for better performance
7. Keep sensitive information in environment variables

## Troubleshooting

Common issues and solutions:

1. **TNS:could not resolve service name**
   - Check if TNS_ADMIN is set correctly
   - Verify wallet files are in the correct location
   - Ensure tnsnames.ora contains the correct service name

2. **ORA-28759: failure to open file**
   - Check wallet permissions
   - Verify wallet location is correct
   - Ensure all wallet files are present

3. **ORA-01017: invalid username/password**
   - Verify ADMIN password is correct
   - Check if the database is running
   - Ensure you're using the correct service name

4. **DPI-1047: Cannot locate Oracle Client library**
   - Check if Oracle Instant Client is installed
   - Verify LD_LIBRARY_PATH is set correctly
   - Ensure ORACLE_HOME is set

For more help, check:
- [cx_Oracle documentation](https://cx-oracle.readthedocs.io/)
- [Oracle Autonomous Database documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/index.html)
- [Python Database Programming Guide](https://python.org/dev/peps/pep-0249/)

