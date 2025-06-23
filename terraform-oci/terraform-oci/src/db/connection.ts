import oracledb, { Connection, Pool, ExecuteOptions } from 'oracledb';
import dotenv from 'dotenv';
import { resolve } from 'path';

// Load environment variables
dotenv.config();

// Database configuration interface
interface DatabaseConfig {
    user: string;
    password: string;
    connectString: string;
    walletLocation: string;
    minConnections: number;
    maxConnections: number;
    connectionTimeout: number;
    debug: boolean;
}

// Custom error class
export class DatabaseError extends Error {
    constructor(
        message: string,
        public readonly errorCode?: number,
        public readonly sqlState?: string
    ) {
        super(message);
        this.name = 'DatabaseError';
    }
}

export class DatabaseConnection {
    private static pool: Pool | null = null;
    private static config: DatabaseConfig;

    /**
     * Initialize the database configuration
     */
    private static initConfig(): DatabaseConfig {
        const config = {
            user: process.env.DB_USER || 'ADMIN',
            password: process.env.DB_PASSWORD,
            connectString: process.env.DB_DSN || 'ORCL_high',
            walletLocation: process.env.TNS_ADMIN || resolve(process.env.HOME || '', '.oracle/wallet/ORCL'),
            minConnections: parseInt(process.env.DB_MIN_CONNECTIONS || '2', 10),
            maxConnections: parseInt(process.env.DB_MAX_CONNECTIONS || '5', 10),
            connectionTimeout: parseInt(process.env.DB_CONNECTION_TIMEOUT || '60000', 10),
            debug: process.env.DB_DEBUG?.toLowerCase() === 'true'
        };

        // Validate required configurations
        if (!config.password) {
            throw new Error('Database password is required');
        }

        return config;
    }

    /**
     * Initialize the database connection pool
     */
    public static async initialize(): Promise<void> {
        if (this.pool) {
            return;
        }

        try {
            this.config = this.initConfig();

            // Configure Oracle client
            oracledb.initOracleClient({ configDir: this.config.walletLocation });
            oracledb.autoCommit = false; // Explicit transaction management

            // Create connection pool
            this.pool = await oracledb.createPool({
                user: this.config.user,
                password: this.config.password,
                connectString: this.config.connectString,
                poolMin: this.config.minConnections,
                poolMax: this.config.maxConnections,
                poolIncrement: 1,
                poolTimeout: this.config.connectionTimeout
            });

            if (this.config.debug) {
                console.log(`Connection pool created with ${this.config.minConnections} to ${this.config.maxConnections} connections`);
            }
        } catch (error) {
            throw new DatabaseError(
                `Failed to initialize database pool: ${error.message}`,
                error.errorNum,
                error.sqlState
            );
        }
    }

    /**
     * Get a connection from the pool
     */
    public static async getConnection(): Promise<Connection> {
        if (!this.pool) {
            await this.initialize();
        }
        try {
            return await this.pool!.getConnection();
        } catch (error) {
            throw new DatabaseError(
                `Failed to get database connection: ${error.message}`,
                error.errorNum,
                error.sqlState
            );
        }
    }

    /**
     * Execute a query with parameters
     */
    public static async executeQuery<T>(
        sql: string,
        params: any[] = [],
        options: ExecuteOptions = {}
    ): Promise<T[]> {
        const connection = await this.getConnection();
        try {
            const result = await connection.execute(sql, params, {
                outFormat: oracledb.OUT_FORMAT_OBJECT,
                ...options
            });
            return result.rows as T[];
        } catch (error) {
            throw new DatabaseError(
                `Query execution failed: ${error.message}`,
                error.errorNum,
                error.sqlState
            );
        } finally {
            await connection.close();
        }
    }

    /**
     * Execute a query within a transaction
     */
    public static async executeTransaction<T>(
        callback: (connection: Connection) => Promise<T>
    ): Promise<T> {
        const connection = await this.getConnection();
        try {
            const result = await callback(connection);
            await connection.commit();
            return result;
        } catch (error) {
            await connection.rollback();
            throw new DatabaseError(
                `Transaction failed: ${error.message}`,
                error.errorNum,
                error.sqlState
            );
        } finally {
            await connection.close();
        }
    }

    /**
     * Test the database connection
     */
    public static async testConnection(): Promise<boolean> {
        try {
            const result = await this.executeQuery('SELECT 1 FROM DUAL');
            return result[0]['1'] === 1;
        } catch (error) {
            console.error('Connection test failed:', error);
            return false;
        }
    }

    /**
     * Close the connection pool
     */
    public static async close(): Promise<void> {
        if (this.pool) {
            await this.pool.close(0);
            this.pool = null;
            if (this.config.debug) {
                console.log('Connection pool closed');
            }
        }
    }
}

// Example usage
async function example() {
    try {
        await DatabaseConnection.initialize();

        // Test connection
        const isConnected = await DatabaseConnection.testConnection();
        if (isConnected) {
            console.log('Successfully connected to the database!');

            // Example query
            const result = await DatabaseConnection.executeQuery('SELECT SYSDATE FROM DUAL');
            console.log('Database time:', result[0]['SYSDATE']);

            // Example transaction
            await DatabaseConnection.executeTransaction(async (connection) => {
                await connection.execute(
                    'INSERT INTO example_table (name) VALUES (:1)',
                    ['test']
                );
                return true;
            });
        }
    } catch (error) {
        console.error('Error:', error);
    } finally {
        await DatabaseConnection.close();
    }
}

if (require.main === module) {
    example().catch(console.error);
}

