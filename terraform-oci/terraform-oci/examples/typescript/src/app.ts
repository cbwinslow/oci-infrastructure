import { DatabasePool } from './database';
import { Order } from './models/order';
import { Product } from './models/product';
import dotenv from 'dotenv';

dotenv.config();

async function demonstrateFeatures() {
    try {
        console.log('Initializing database connection pool...');
        await DatabasePool.initialize();

        // Create tables
        console.log('\nCreating tables...');
        await createTables();

        // Insert sample products
        console.log('\nInserting sample products...');
        const products = [
            { name: 'Gaming Laptop', price: 1299.99, description: 'High-performance gaming laptop' },
            { name: 'Wireless Mouse', price: 49.99, description: 'Ergonomic wireless mouse' },
            { name: 'Mechanical Keyboard', price: 129.99, description: 'RGB mechanical keyboard' }
        ];

        const productIds = await Promise.all(
            products.map(product => insertProduct(product))
        );

        // Create sample orders
        console.log('\nCreating sample orders...');
        const orders = [
            { productId: productIds[0], quantity: 1, totalPrice: 1299.99 },
            { productId: productIds[1], quantity: 2, totalPrice: 99.98 },
            { productId: productIds[2], quantity: 1, totalPrice: 129.99 }
        ];

        const orderIds = await Promise.all(
            orders.map(order => createOrder(order))
        );

        // Demonstrate transaction
        console.log('\nDemonstrating transaction...');
        await demonstrateTransaction(orderIds[0], orderIds[1], 50.00);

        // Query data
        console.log('\nQuerying orders with products...');
        const ordersWithProducts = await getOrdersWithProducts();
        console.log('Orders:', JSON.stringify(ordersWithProducts, null, 2));

        // Clean up
        console.log('\nCleaning up...');
        await cleanup();

    } catch (error) {
        console.error('Error in demonstration:', error);
    } finally {
        await DatabasePool.close();
    }
}

async function createTables(): Promise<void> {
    const connection = await DatabasePool.getConnection();
    try {
        // Create products table
        await connection.execute(`
            CREATE TABLE products (
                id NUMBER GENERATED ALWAYS AS IDENTITY,
                name VARCHAR2(100) NOT NULL,
                price NUMBER(10,2) NOT NULL,
                description VARCHAR2(500),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT products_pk PRIMARY KEY (id)
            )
        `);

        // Create orders table
        await connection.execute(`
            CREATE TABLE orders (
                id NUMBER GENERATED ALWAYS AS IDENTITY,
                product_id NUMBER NOT NULL,
                quantity NUMBER(10) NOT NULL,
                total_price NUMBER(10,2) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT orders_pk PRIMARY KEY (id),
                CONSTRAINT orders_products_fk FOREIGN KEY (product_id)
                    REFERENCES products(id)
            )
        `);

        console.log('Tables created successfully');
    } finally {
        await connection.close();
    }
}

async function insertProduct(product: Product): Promise<number> {
    const connection = await DatabasePool.getConnection();
    try {
        const result = await connection.execute(
            `INSERT INTO products (name, price, description)
             VALUES (:name, :price, :description)
             RETURNING id INTO :id`,
            {
                name: product.name,
                price: product.price,
                description: product.description,
                id: { type: DatabasePool.oracledb.NUMBER, dir: DatabasePool.oracledb.BIND_OUT }
            }
        );

        await connection.commit();
        return result.outBinds.id[0];
    } finally {
        await connection.close();
    }
}

async function createOrder(order: Order): Promise<number> {
    const connection = await DatabasePool.getConnection();
    try {
        const result = await connection.execute(
            `INSERT INTO orders (product_id, quantity, total_price)
             VALUES (:product_id, :quantity, :total_price)
             RETURNING id INTO :id`,
            {
                product_id: order.productId,
                quantity: order.quantity,
                total_price: order.totalPrice,
                id: { type: DatabasePool.oracledb.NUMBER, dir: DatabasePool.oracledb.BIND_OUT }
            }
        );

        await connection.commit();
        return result.outBinds.id[0];
    } finally {
        await connection.close();
    }
}

async function demonstrateTransaction(
    fromOrderId: number,
    toOrderId: number,
    amount: number
): Promise<void> {
    const connection = await DatabasePool.getConnection();
    try {
        await connection.execute('BEGIN');

        // Update first order
        await connection.execute(
            `UPDATE orders 
             SET total_price = total_price - :1
             WHERE id = :2`,
            [amount, fromOrderId]
        );

        // Update second order
        await connection.execute(
            `UPDATE orders 
             SET total_price = total_price + :1
             WHERE id = :2`,
            [amount, toOrderId]
        );

        await connection.execute('COMMIT');
        console.log(`Successfully transferred ${amount} between orders`);
    } catch (error) {
        await connection.execute('ROLLBACK');
        throw error;
    } finally {
        await connection.close();
    }
}

async function getOrdersWithProducts(): Promise<any[]> {
    const connection = await DatabasePool.getConnection();
    try {
        const result = await connection.execute(
            `SELECT 
                o.id as order_id,
                o.quantity,
                o.total_price,
                o.created_at as order_date,
                p.id as product_id,
                p.name as product_name,
                p.price as product_price,
                p.description as product_description
             FROM orders o
             JOIN products p ON o.product_id = p.id
             ORDER BY o.created_at DESC`,
            [],
            { outFormat: DatabasePool.oracledb.OUT_FORMAT_OBJECT }
        );

        return result.rows || [];
    } finally {
        await connection.close();
    }
}

async function cleanup(): Promise<void> {
    const connection = await DatabasePool.getConnection();
    try {
        await connection.execute('DROP TABLE orders');
        await connection.execute('DROP TABLE products');
        console.log('Tables dropped successfully');
    } finally {
        await connection.close();
    }
}

// Run the demonstration
demonstrateFeatures().catch(console.error);

