#!/bin/bash

# Deployment script for OCI Free Tier Infrastructure
# This script uses both Terraform and OCI CLI to deploy infrastructure

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="${PROJECT_ROOT}/free-tier"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/deployment_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="${LOG_DIR}/error_$(date +%Y%m%d_%H%M%S).log"

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

error_log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $1" | tee -a "$ERROR_LOG" >&2
}

# Check for required tools
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for OCI CLI
    if ! command -v oci &> /dev/null; then
        missing_tools+=("oci")
    fi
    
    # Check for Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error_log "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    log "All prerequisites met"
}

# Validate OCI CLI configuration
validate_oci_config() {
    log "Validating OCI CLI configuration..."
    
    if ! oci iam region list > /dev/null 2>&1; then
        error_log "OCI CLI is not properly configured"
        exit 1
    fi
    
    # Get and log tenancy details
    local tenancy_name=$(oci iam tenancy get --tenancy-id $(oci iam compartment list --all | jq -r '.data[0]."compartment-id"') | jq -r '.data.name')
    log "Connected to tenancy: $tenancy_name"
}

# Create Terraform configuration
create_terraform_config() {
    log "Creating Terraform configuration..."
    
    # Create directory structure
    mkdir -p "$TERRAFORM_DIR"
    
    # Get Ubuntu image OCID for us-ashburn-1
    log "Getting latest Ubuntu image OCID..."
    local image_ocid=$(oci compute image list \
        --compartment-id "$TF_VAR_compartment_id" \
        --operating-system "Canonical Ubuntu" \
        --operating-system-version "20.04" \
        --shape "VM.Standard.E2.1.Micro" \
        --region us-ashburn-1 \
        --query 'data[0].id' \
        --raw-output)
    
    log "Using image OCID: $image_ocid"
    
    # Update terraform.tfvars
    cat > "$TERRAFORM_DIR/terraform.tfvars" << EOF
# Authentication
tenancy_ocid     = "${TF_VAR_tenancy_ocid}"
user_ocid        = "${TF_VAR_user_ocid}"
fingerprint      = "${TF_VAR_fingerprint}"
private_key_path = "${TF_VAR_private_key_path}"
compartment_id   = "${TF_VAR_compartment_id}"

# Region
region = "us-ashburn-1"

# Instance
instance_image_id = "${image_ocid}"
ssh_public_key    = "${TF_VAR_ssh_public_key}"

# Database
db_name          = "FREETIERDB"
db_password      = "${TF_VAR_db_password}"
db_workload      = "OLTP"

# Network
vcn_cidr         = "10.0.0.0/16"
subnet_cidr      = "10.0.1.0/24"

# Block Volume
volume_size_gb   = 50
EOF
    
    log "Terraform configuration created"
}

# Initialize and apply Terraform
deploy_terraform() {
    log "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    
    terraform init 2>&1 | tee -a "$LOG_FILE"
    
    log "Creating Terraform plan..."
    terraform plan -out=tfplan 2>&1 | tee -a "$LOG_FILE"
    
    log "Applying Terraform configuration..."
    terraform apply -auto-approve tfplan 2>&1 | tee -a "$LOG_FILE"
    
    # Save Terraform outputs
    terraform output -json > "${LOG_DIR}/terraform_output.json"
    log "Terraform outputs saved to terraform_output.json"
}

# Configure instance post-deployment
configure_instance() {
    log "Configuring compute instance..."
    
    # Get instance public IP
    local instance_ip=$(jq -r '.instance_public_ip.value' "${LOG_DIR}/terraform_output.json")
    
    # Wait for instance to be ready
    log "Waiting for instance to be accessible..."
    while ! nc -z $instance_ip 22; do
        sleep 5
    done
    
    # Configure instance
    ssh -o StrictHostKeyChecking=no ubuntu@$instance_ip << 'EOF'
        # Install Oracle instant client
        sudo apt-get update
        sudo apt-get install -y alien libaio1
        
        # Create Oracle directories
        mkdir -p ~/oracle/wallet
        mkdir -p ~/oracle/network/admin
        
        # Set environment variables
        echo 'export TNS_ADMIN=~/oracle/network/admin' >> ~/.bashrc
        echo 'export LD_LIBRARY_PATH=/usr/lib/oracle/client64/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
        
        # Mount block volume
        sudo mkfs.ext4 /dev/sdb
        sudo mkdir /data
        sudo mount /dev/sdb /data
        echo '/dev/sdb /data ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab
EOF
    
    log "Instance configuration completed"
}

# Configure database post-deployment
configure_database() {
    log "Configuring Autonomous Database..."
    
    # Get database OCID
    local db_ocid=$(jq -r '.autonomous_database_id.value' "${LOG_DIR}/terraform_output.json")
    
    # Download wallet
    log "Downloading database wallet..."
    oci db autonomous-database generate-wallet \
        --autonomous-database-id "$db_ocid" \
        --password "${TF_VAR_wallet_password}" \
        --file "${LOG_DIR}/wallet.zip"
    
    # Create database user and grant permissions
    log "Creating database user..."
    local db_url=$(jq -r '.database_url.value' "${LOG_DIR}/terraform_output.json")
    
    # Save connection information
    cat > "${LOG_DIR}/connection_info.txt" << EOF
Database URL: $db_url
Wallet Location: ${LOG_DIR}/wallet.zip
Admin User: admin
Application User: app_user
EOF
    
    log "Database configuration completed"
}

# Main deployment function
main() {
    log "Starting deployment of OCI Free Tier infrastructure..."
    
    check_prerequisites
    validate_oci_config
    create_terraform_config
    deploy_terraform
    configure_instance
    configure_database
    
    log "Deployment completed successfully!"
    
    # Print summary
    cat > "${LOG_DIR}/deployment_summary.txt" << EOF
OCI Free Tier Infrastructure Deployment Summary
============================================

Resources Created:
- Compute Instance (VM.Standard.E2.1.Micro)
- Autonomous Database (1 OCPU, 1TB storage)
- 50GB Block Volume
- Virtual Cloud Network
- Public Subnet
- Security Lists
- Internet Gateway

Connection Information:
- Instance Public IP: $(jq -r '.instance_public_ip.value' "${LOG_DIR}/terraform_output.json")
- Database URL: $(jq -r '.database_url.value' "${LOG_DIR}/terraform_output.json")

All logs and configuration files are available in: ${LOG_DIR}
EOF
    
    cat "${LOG_DIR}/deployment_summary.txt"
}

# Error handling
set -e
trap 'error_log "An error occurred on line $LINENO. Check error log for details."' ERR

# Run main function
main "$@"

