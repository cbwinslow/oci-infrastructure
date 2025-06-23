import { DatabaseOperations } from './database';

async function runExample() {
  try {
    // Create tables
    console.log('Creating tables...');
    await DatabaseOperations.createTables();

    // Insert products
    console.log('\nInserting products...');
    const products = [
      { name: 'Laptop', price: 999.99 },
      { name: 'Mouse', price: 24.99 },
      { name: 'Keyboard', price: 59.99 },
      { name: 'Monitor', price: 299.99 }
    ];

    const productIds = await Promise.all(
      products.map(product => DatabaseOperations.insertProduct(product))
    );

    console.log('Products inserted with IDs:', productIds);

    // Create orders
    console.log('\nCreating orders...');
    const orders = [
      { productId: productIds[0], quantity: 2, totalPrice: 1999.98 },
      { productId: productIds[1], quantity: 5, totalPrice: 124.95 },
      { productId: productIds[2], quantity: 3, totalPrice: 179.97 },
      { productId: productIds[3], quantity: 1, totalPrice: 299.99 }
    ];

    const orderIds = await Promise.all(
      orders.map(order => DatabaseOperations.createOrder(order))
    );

    console.log('Orders created with IDs:', orderIds);

    // Query all orders
    console.log('\nQuerying all orders...');
    const allOrders = await DatabaseOperations.getAllOrders();
    
    console.log('\nOrder Details:');
    console.log('-'.repeat(70));
    console.log('Order ID  Product              Quantity  Total Price  Order Date');
    console.log('-'.repeat(70));
    
    allOrders.forEach(order => {
      console.log(
        `${order.ORDER_ID.toString().padEnd(9)} ` +
        `${order.PRODUCT_NAME.padEnd(20)} ` +
        `${order.QUANTITY.toString().padEnd(9)} ` +
        `$${order.TOTAL_PRICE.toFixed(2).padEnd(11)} ` +
        `${new Date(order.ORDER_DATE).toISOString().split('T')[0]}`
      );
    });

    // Get specific order details
    console.log('\nGetting details for first order...');
    const orderDetails = await DatabaseOperations.getOrderDetails(orderIds[0]);
    console.log('First order details:', orderDetails);

    // Cleanup
    console.log('\nCleaning up...');
    await DatabaseOperations.cleanupTables();

  } catch (error) {
    console.error('Error in example:', error);
  }
}

// Run the example
runExample().then(() => {
  console.log('\nExample completed!');
  process.exit(0);
}).catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

