import oracledb, { Connection, Pool } from 'oracledb';
import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config();

// Database configuration interface
interface DatabaseConfig {
  user: string;
  password: string;
  connectString: string;
  libDir: string;
  configDir: string;
}

// Database configuration
const dbConfig: DatabaseConfig = {
  user: 'ADMIN',
  password: process.env.DB_PASSWORD || '',
  connectString: 'ORCL_high',
  libDir: process.env.ORACLE_HOME || '/usr/lib/oracle/client64',
  configDir: process.env.TNS_ADMIN || path.join(process.env.HOME || '', '.oracle/wallet/ORCL'),
};

// Initialize Oracle client
oracledb.initOracleClient({ libDir: dbConfig.configDir });
oracledb.autoCommit = true;

// Database connection pool
class DatabasePool {
  private static pool: Pool | null = null;

  static async initialize(config: DatabaseConfig): Promise<Pool> {
    if (!this.pool) {
      this.pool = await oracledb.createPool({
        user: config.user,
        password: config.password,
        connectString: config.connectString,
        poolMin: 2,
        poolMax: 5,
        poolIncrement: 1,
      });
    }
    return this.pool;
  }

  static async getConnection(): Promise<Connection> {
    if (!this.pool) {
      await this.initialize(dbConfig);
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

// Product interface
interface Product {
  productId?: number;
  name: string;
  price: number;
  createdDate?: Date;
}

// Order interface
interface Order {
  orderId?: number;
  productId: number;
  quantity: number;
  totalPrice: number;
  orderDate?: Date;
}

// Database operations class
export class DatabaseOperations {
  static async createTables(): Promise<void> {
    const connection = await DatabasePool.getConnection();
    
    try {
      // Create products table
      await connection.execute(`
        CREATE TABLE products (
          product_id NUMBER GENERATED ALWAYS AS IDENTITY,
          name VARCHAR2(100) NOT NULL,
          price NUMBER(10,2) NOT NULL,
          created_date DATE DEFAULT SYSDATE,
          CONSTRAINT products_pk PRIMARY KEY (product_id)
        )
      `);

      // Create orders table
      await connection.execute(`
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
      `);

      console.log('Tables created successfully');
    } finally {
      await connection.close();
    }
  }

  static async insertProduct(product: Product): Promise<number> {
    const connection = await DatabasePool.getConnection();
    
    try {
      const result = await connection.execute(
        `INSERT INTO products (name, price) 
         VALUES (:name, :price) 
         RETURNING product_id INTO :product_id`,
        {
          name: product.name,
          price: product.price,
          product_id: { type: oracledb.NUMBER, dir: oracledb.BIND_OUT }
        }
      );

      return result.outBinds.product_id[0];
    } finally {
      await connection.close();
    }
  }

  static async createOrder(order: Order): Promise<number> {
    const connection = await DatabasePool.getConnection();
    
    try {
      const result = await connection.execute(
        `INSERT INTO orders (product_id, quantity, total_price) 
         VALUES (:product_id, :quantity, :total_price) 
         RETURNING order_id INTO :order_id`,
        {
          product_id: order.productId,
          quantity: order.quantity,
          total_price: order.totalPrice,
          order_id: { type: oracledb.NUMBER, dir: oracledb.BIND_OUT }
        }
      );

      return result.outBinds.order_id[0];
    } finally {
      await connection.close();
    }
  }

  static async getOrderDetails(orderId: number): Promise<any> {
    const connection = await DatabasePool.getConnection();
    
    try {
      const result = await connection.execute(
        `SELECT 
           o.order_id,
           p.name as product_name,
           o.quantity,
           o.total_price,
           o.order_date
         FROM orders o
         JOIN products p ON o.product_id = p.product_id
         WHERE o.order_id = :order_id`,
        [orderId],
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );

      return result.rows?.[0] || null;
    } finally {
      await connection.close();
    }
  }

  static async getAllOrders(): Promise<any[]> {
    const connection = await DatabasePool.getConnection();
    
    try {
      const result = await connection.execute(
        `SELECT 
           o.order_id,
           p.name as product_name,
           o.quantity,
           o.total_price,
           o.order_date
         FROM orders o
         JOIN products p ON o.product_id = p.product_id
         ORDER BY o.order_date DESC`,
        [],
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );

      return result.rows || [];
    } finally {
      await connection.close();
    }
  }

  static async cleanupTables(): Promise<void> {
    const connection = await DatabasePool.getConnection();
    
    try {
      await connection.execute('DROP TABLE orders');
      await connection.execute('DROP TABLE products');
      console.log('Tables dropped successfully');
    } finally {
      await connection.close();
    }
  }
}

