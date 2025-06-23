import os
import cx_Oracle
from contextlib import contextmanager
from typing import Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class DatabaseConfig:
    """Database configuration class"""
    def __init__(self):
        self.user = os.getenv('DB_USER', 'ADMIN')
        self.password = os.getenv('DB_PASSWORD')
        self.dsn = os.getenv('DB_DSN', 'ORCL_high')
        self.wallet_location = os.getenv('TNS_ADMIN', os.path.expanduser('~/.oracle/wallet/ORCL'))
        self.min_connections = int(os.getenv('DB_MIN_CONNECTIONS', '2'))
        self.max_connections = int(os.getenv('DB_MAX_CONNECTIONS', '5'))
        self.connection_timeout = int(os.getenv('DB_CONNECTION_TIMEOUT', '60'))
        self.debug = os.getenv('DB_DEBUG', 'false').lower() == 'true'

        # Validate required configurations
        if not all([self.user, self.password, self.dsn, self.wallet_location]):
            raise ValueError("Missing required database configuration. Check environment variables.")

class DatabaseConnection:
    """Database connection manager"""
    _pool: Optional[cx_Oracle.SessionPool] = None
    _config: Optional[DatabaseConfig] = None

    @classmethod
    def initialize(cls, config: Optional[DatabaseConfig] = None) -> None:
        """Initialize the database connection pool"""
        if cls._pool is not None:
            return

        cls._config = config or DatabaseConfig()
        
        try:
            # Set Oracle Client configuration
            if cls._config.wallet_location:
                os.environ['TNS_ADMIN'] = cls._config.wallet_location

            # Create the connection pool
            cls._pool = cx_Oracle.SessionPool(
                user=cls._config.user,
                password=cls._config.password,
                dsn=cls._config.dsn,
                min=cls._config.min_connections,
                max=cls._config.max_connections,
                increment=1,
                encoding="UTF-8",
                timeout=cls._config.connection_timeout
            )

            if cls._config.debug:
                print(f"Connection pool created with {cls._config.min_connections} to "
                      f"{cls._config.max_connections} connections")

        except cx_Oracle.Error as error:
            raise ConnectionError(f"Failed to initialize database pool: {error}")

    @classmethod
    def get_pool(cls) -> cx_Oracle.SessionPool:
        """Get the connection pool, initializing if necessary"""
        if cls._pool is None:
            cls.initialize()
        return cls._pool

    @classmethod
    def close(cls) -> None:
        """Close the connection pool"""
        if cls._pool is not None:
            cls._pool.close()
            cls._pool = None
            if cls._config and cls._config.debug:
                print("Connection pool closed")

@contextmanager
def get_connection():
    """Context manager for database connections"""
    connection = None
    try:
        connection = DatabaseConnection.get_pool().acquire()
        yield connection
    finally:
        if connection:
            DatabaseConnection.get_pool().release(connection)

class DatabaseError(Exception):
    """Custom database error class"""
    def __init__(self, message: str, error_code: Optional[int] = None):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)

def test_connection() -> bool:
    """Test the database connection"""
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute("SELECT 1 FROM DUAL")
            result = cursor.fetchone()
            return result[0] == 1
    except Exception as e:
        print(f"Connection test failed: {e}")
        return False

# Example usage
if __name__ == "__main__":
    try:
        # Initialize the connection pool
        DatabaseConnection.initialize()
        
        # Test the connection
        if test_connection():
            print("Successfully connected to the database!")
            
            # Example query
            with get_connection() as connection:
                cursor = connection.cursor()
                cursor.execute("SELECT SYSDATE FROM DUAL")
                result = cursor.fetchone()
                print(f"Database time: {result[0]}")
                
    except Exception as e:
        print(f"Error: {e}")
    finally:
        DatabaseConnection.close()

