#!/bin/bash

# Script to initialize secure storage for OCI credentials

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECURE_DIR="${PROJECT_ROOT}/secure"
CREDS_DIR="${SECURE_DIR}/credentials"
LOG_DIR="${PROJECT_ROOT}/logs"

# Create directories with secure permissions
setup_directories() {
    echo "Setting up secure directories..."
    
    # Create directories
    mkdir -p "$SECURE_DIR"
    mkdir -p "$CREDS_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$CREDS_DIR/backups"
    
    # Set permissions
    chmod 700 "$SECURE_DIR"
    chmod 700 "$CREDS_DIR"
    chmod 700 "$CREDS_DIR/backups"
    
    # Create .gitignore to prevent committing sensitive files
    cat > "${SECURE_DIR}/.gitignore" << EOF
# Ignore everything in this directory
*
# Except this file
!.gitignore
EOF
    
    echo "Secure directories created with appropriate permissions"
}

# Initialize GPG if needed
init_gpg() {
    if ! command -v gpg > /dev/null; then
        echo "Installing GPG..."
        sudo apt-get update
        sudo apt-get install -y gnupg
    fi
    
    # Check if GPG is properly configured
    if ! gpg --list-keys > /dev/null 2>&1; then
        echo "Initializing GPG..."
        gpg --gen-key
    fi
}

# Create helper scripts
create_helper_scripts() {
    # Create script to load credentials
    cat > "${SECURE_DIR}/load_credentials.sh" << 'EOF'
#!/bin/bash
source $(dirname "$0")/../scripts/manage_credentials.sh load
EOF
    chmod +x "${SECURE_DIR}/load_credentials.sh"
    
    # Create script to store credentials
    cat > "${SECURE_DIR}/store_credentials.sh" << 'EOF'
#!/bin/bash
source $(dirname "$0")/../scripts/manage_credentials.sh store
EOF
    chmod +x "${SECURE_DIR}/store_credentials.sh"
}

# Create README
create_readme() {
    cat > "${SECURE_DIR}/README.md" << 'EOF'
# Secure Credential Storage

This directory contains securely encrypted OCI credentials and related files.

## Directory Structure

- `credentials/` - Contains encrypted credential files
  - `oci_credentials.enc` - Encrypted OCI credentials
  - `backups/` - Backup directory for credentials

## Usage

1. Store credentials:
   ```bash
   ./store_credentials.sh
   ```

2. Load credentials:
   ```bash
   source ./load_credentials.sh
   ```

## Security

- All files are encrypted using GPG
- Directory permissions are set to 700 (user only)
- Credentials are never stored in plain text
- Automatic backup system included

## Important Notes

- Never commit unencrypted credentials
- Keep backups of your GPG keys
- Regularly rotate credentials
- Always validate credentials after loading
EOF
}

# Main function
main() {
    echo "Initializing secure storage for OCI credentials..."
    
    # Check if already initialized
    if [ -f "${SECURE_DIR}/.initialized" ]; then
        echo "Secure storage already initialized"
        exit 0
    fi
    
    # Setup
    setup_directories
    init_gpg
    create_helper_scripts
    create_readme
    
    # Mark as initialized
    touch "${SECURE_DIR}/.initialized"
    
    echo "Secure storage initialized successfully!"
    echo "Use './manage_credentials.sh' to manage your credentials"
}

# Run main function
main

