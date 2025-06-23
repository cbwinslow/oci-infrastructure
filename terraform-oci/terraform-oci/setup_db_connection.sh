#!/bin/bash

# Script to set up database connection configuration
# Usage: ./setup_db_connection.sh

echo "Setting up database connection configuration..."

# Create wallet directory if it doesn't exist
mkdir -p wallet
mkdir -p ${HOME}/.oracle/wallet/${DB_NAME}

# Check if wallet file exists
WALLET_FILE="wallet/${DB_NAME}_wallet.zip"
if [ ! -f "$WALLET_FILE" ]; then
    echo "Error: Wallet file not found at $WALLET_FILE"
    exit 1
fi

# Extract wallet to Oracle client directory
unzip -o "$WALLET_FILE" -d "${HOME}/.oracle/wallet/${DB_NAME}"

# Generate tnsnames.ora configuration
cat > "${HOME}/.oracle/wallet/${DB_NAME}/tnsnames.ora" << EOF
${DB_NAME}_high = (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=${DB_HOST}))(connect_data=(service_name=${DB_NAME}_high))(security=(ssl_server_dn_match=yes)))
${DB_NAME}_low = (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=${DB_HOST}))(connect_data=(service_name=${DB_NAME}_low))(security=(ssl_server_dn_match=yes)))
${DB_NAME}_medium = (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=${DB_HOST}))(connect_data=(service_name=${DB_NAME}_medium))(security=(ssl_server_dn_match=yes)))
EOF

# Generate sqlnet.ora configuration
cat > "${HOME}/.oracle/wallet/${DB_NAME}/sqlnet.ora" << EOF
WALLET_LOCATION = (SOURCE = (METHOD = file) (METHOD_DATA = (DIRECTORY="${HOME}/.oracle/wallet/${DB_NAME}")))
SSL_SERVER_DN_MATCH=yes
EOF

echo "Database connection configuration completed!"
echo "Wallet location: ${HOME}/.oracle/wallet/${DB_NAME}"
echo
echo "Connection string examples:"
echo "Python (cx_Oracle):"
echo "dsn = '${DB_NAME}_high'"
echo "connection = cx_Oracle.connect(username='ADMIN', password='your_password', dsn=dsn, config_dir='${HOME}/.oracle/wallet/${DB_NAME}')"
echo
echo "SQLPlus:"
echo "sqlplus admin@${DB_NAME}_high"
echo
echo "Remember to set the following environment variables:"
echo "export TNS_ADMIN=${HOME}/.oracle/wallet/${DB_NAME}"
echo "export ORACLE_HOME=/usr/lib/oracle/current/client64"
echo "export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH"

