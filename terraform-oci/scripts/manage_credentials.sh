#!/bin/bash

# Credentials management script for OCI and Free Tier access
# This script manages encrypted storage of credentials

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CREDS_DIR="${PROJECT_ROOT}/secure/credentials"
CREDS_FILE="${CREDS_DIR}/oci_credentials.enc"
KEY_FILE="${CREDS_DIR}/key.gpg"
CONFIG_DIR="${HOME}/.oci"
BACKUP_DIR="${CREDS_DIR}/backups"

# Create necessary directories
mkdir -p "$CREDS_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$CONFIG_DIR"

# Logging
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/credentials_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to encrypt credentials
encrypt_credentials() {
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
# OCI Credentials - $(date)
tenancy_ocid=${TF_VAR_tenancy_ocid}
user_ocid=${TF_VAR_user_ocid}
fingerprint=${TF_VAR_fingerprint}
region=${TF_VAR_region:-us-ashburn-1}
compartment_id=${TF_VAR_compartment_id}

# Database Credentials
db_password=${TF_VAR_db_password}
wallet_password=${TF_VAR_wallet_password}

# SSH Keys
private_key_path=${TF_VAR_private_key_path}
ssh_public_key=${TF_VAR_ssh_public_key}
EOF

    # Encrypt the file using gpg
    gpg --symmetric --cipher-algo AES256 --output "$CREDS_FILE" "$temp_file"
    rm "$temp_file"
    
    log "Credentials encrypted and stored in $CREDS_FILE"
}

# Function to decrypt credentials
decrypt_credentials() {
    if [ ! -f "$CREDS_FILE" ]; then
        log "Error: Credentials file not found"
        return 1
    fi

    local temp_file=$(mktemp)
    gpg --quiet --decrypt "$CREDS_FILE" > "$temp_file"
    
    # Source the decrypted credentials
    source "$temp_file"
    rm "$temp_file"
    
    # Export as environment variables
    export TF_VAR_tenancy_ocid="$tenancy_ocid"
    export TF_VAR_user_ocid="$user_ocid"
    export TF_VAR_fingerprint="$fingerprint"
    export TF_VAR_region="${region:-us-ashburn-1}"
    export TF_VAR_compartment_id="$compartment_id"
    export TF_VAR_db_password="$db_password"
    export TF_VAR_wallet_password="$wallet_password"
    export TF_VAR_private_key_path="$private_key_path"
    export TF_VAR_ssh_public_key="$ssh_public_key"
    
    log "Credentials decrypted and exported as environment variables"
}

# Function to backup credentials
backup_credentials() {
    if [ ! -f "$CREDS_FILE" ]; then
        log "Error: No credentials file to backup"
        return 1
    fi

    local backup_file="${BACKUP_DIR}/oci_credentials_$(date +%Y%m%d_%H%M%S).enc"
    cp "$CREDS_FILE" "$backup_file"
    log "Credentials backed up to $backup_file"
}

# Function to store OCI config file
store_oci_config() {
    local config_file="$CONFIG_DIR/config"
    local private_key="$CONFIG_DIR/oci_api_key.pem"

    # Create OCI config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"

    # Create config file
    cat > "$config_file" << EOF
[DEFAULT]
user=${TF_VAR_user_ocid}
fingerprint=${TF_VAR_fingerprint}
tenancy=${TF_VAR_tenancy_ocid}
region=${TF_VAR_region:-us-ashburn-1}
key_file=${private_key}
EOF

    chmod 600 "$config_file"
    
    # Copy private key if provided
    if [ -n "$TF_VAR_private_key_path" ] && [ -f "$TF_VAR_private_key_path" ]; then
        cp "$TF_VAR_private_key_path" "$private_key"
        chmod 600 "$private_key"
    fi

    log "OCI config file created at $config_file"
}

# Function to validate credentials
validate_credentials() {
    log "Validating OCI credentials..."
    
    if ! command -v oci >/dev/null 2>&1; then
        log "Error: OCI CLI not installed"
        return 1
    }

    if ! oci iam region list >/dev/null 2>&1; then
        log "Error: Invalid OCI credentials"
        return 1
    }

    log "OCI credentials validated successfully"
}

# Function to show status
show_status() {
    echo "OCI Credentials Status:"
    echo "======================"
    echo "Credentials file: $([ -f "$CREDS_FILE" ] && echo "Present" || echo "Missing")"
    echo "OCI config: $([ -f "$CONFIG_DIR/config" ] && echo "Present" || echo "Missing")"
    echo "Private key: $([ -f "$CONFIG_DIR/oci_api_key.pem" ] && echo "Present" || echo "Missing")"
    echo "Latest backup: $(ls -t "${BACKUP_DIR}"/*.enc 2>/dev/null | head -1 || echo "No backups")"
    
    if [ -f "$CREDS_FILE" ]; then
        echo -n "Credentials validation: "
        if validate_credentials >/dev/null 2>&1; then
            echo "Valid"
        else
            echo "Invalid"
        fi
    fi
}

# Main menu function
main_menu() {
    while true; do
        echo
        echo "OCI Credentials Management"
        echo "========================="
        echo "1. Store new credentials"
        echo "2. Load existing credentials"
        echo "3. Backup credentials"
        echo "4. Update OCI config"
        echo "5. Show status"
        echo "6. Validate credentials"
        echo "7. Exit"
        echo
        read -p "Select an option: " choice

        case $choice in
            1)
                encrypt_credentials
                store_oci_config
                ;;
            2)
                decrypt_credentials
                ;;
            3)
                backup_credentials
                ;;
            4)
                store_oci_config
                ;;
            5)
                show_status
                ;;
            6)
                validate_credentials
                ;;
            7)
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

# If no arguments, show menu
if [ $# -eq 0 ]; then
    main_menu
else
    # Handle command line arguments
    case "$1" in
        "store")
            encrypt_credentials
            store_oci_config
            ;;
        "load")
            decrypt_credentials
            ;;
        "backup")
            backup_credentials
            ;;
        "validate")
            validate_credentials
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 {store|load|backup|validate|status}"
            exit 1
            ;;
    esac
fi

