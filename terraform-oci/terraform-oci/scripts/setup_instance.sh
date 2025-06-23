#!/bin/bash

# Script to set up the compute instance for database access
# Usage: ./setup_instance.sh <instance_public_ip>

INSTANCE_IP=$1
DB_NAME=${2:-ORCL}  # Default to ORCL if not provided

if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: $0 <instance_public_ip> [db_name]"
    exit 1
fi

echo "Setting up instance at $INSTANCE_IP..."

# Wait for instance to be ready
echo "Waiting for SSH to be available..."
while ! nc -z $INSTANCE_IP 22; do   
    sleep 5
done

# Copy wallet files
echo "Copying wallet files..."
scp -r wallet/${DB_NAME}_wallet.zip ubuntu@${INSTANCE_IP}:/home/ubuntu/.oracle/wallet/${DB_NAME}/

# SSH into instance and complete setup
ssh ubuntu@${INSTANCE_IP} << 'EOF'
    # Extract wallet files
    cd ~/.oracle/wallet/${DB_NAME}
    unzip ${DB_NAME}_wallet.zip
    rm ${DB_NAME}_wallet.zip

    # Set up environment variables
    echo "export TNS_ADMIN=$HOME/.oracle/wallet/${DB_NAME}" >> ~/.bashrc
    echo "export LD_LIBRARY_PATH=/usr/lib/oracle/client64/lib:$LD_LIBRARY_PATH" >> ~/.bashrc
    echo "export ORACLE_HOME=/usr/lib/oracle/client64" >> ~/.bashrc

    # Create sqlnet.ora
    cat > sqlnet.ora << 'EOL'
WALLET_LOCATION = (SOURCE = (METHOD = file) (METHOD_DATA = (DIRECTORY="$TNS_ADMIN")))
SSL_SERVER_DN_MATCH=yes
EOL

    # Set proper permissions
    chmod 600 ~/.oracle/wallet/${DB_NAME}/*
    
    # Install Python and Node.js development tools
    sudo apt-get update
    sudo apt-get install -y python3-pip nodejs npm
    
    # Install Python Oracle packages
    pip3 install cx-Oracle python-dotenv
    
    # Install Node.js Oracle packages
    mkdir -p ~/app
    cd ~/app
    npm init -y
    npm install oracledb dotenv typescript ts-node @types/node
    
    echo "Setup completed successfully!"
EOF

echo "Instance setup completed!"
echo "You can now connect to the instance using: ssh ubuntu@${INSTANCE_IP}"
echo "Database wallet is configured at: /home/ubuntu/.oracle/wallet/${DB_NAME}"

