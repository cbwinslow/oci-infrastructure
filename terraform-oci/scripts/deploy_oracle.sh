#!/bin/bash

# Script to deploy Oracle infrastructure assets
# This script focuses on OCI Free Tier resources

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_ROOT}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/deploy_oracle_${TIMESTAMP}.log"

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to check OCI CLI configuration
check_oci_config() {
    log "Checking OCI CLI configuration..."
    
    if ! command -v oci >/dev/null 2>&1; then
        log "Error: OCI CLI not installed"
        return 1
    }

    if ! oci iam region list >/dev/null 2>&1; then
        log "Error: OCI CLI not configured. Please run 'oci setup config'"
        return 1
    }

    log "OCI CLI configuration verified"
}

# Function to validate required environment variables
validate_env_vars() {
    log "Validating environment variables..."
    
    required_vars=(
        "TF_VAR_tenancy_ocid"
        "TF_VAR_user_ocid"
        "TF_VAR_fingerprint"
        "TF_VAR_private_key_path"
        "TF_VAR_compartment_id"
        "TF_VAR_region"
    )

    missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log "Error: Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi

    log "Environment variables validated"
}

# Function to initialize Terraform
init_terraform() {
    log "Initializing Terraform..."
    
    cd "$PROJECT_ROOT"
    terraform init
    
    if [ $? -ne 0 ]; then
        log "Error: Terraform initialization failed"
        return 1
    fi
    
    log "Terraform initialized successfully"
}

# Function to create Terraform plan
create_plan() {
    log "Creating Terraform plan..."
    
    terraform plan -out=tfplan
    
    if [ $? -ne 0 ]; then
        log "Error: Terraform plan creation failed"
        return 1
    }
    
    log "Terraform plan created successfully"
}

# Function to apply Terraform configuration
apply_terraform() {
    log "Applying Terraform configuration..."
    
    terraform apply -auto-approve tfplan
    
    if [ $? -ne 0 ]; then
        log "Error: Terraform apply failed"
        return 1
    }
    
    log "Terraform configuration applied successfully"
}

# Function to save outputs
save_outputs() {
    log "Saving deployment outputs..."
    
    mkdir -p "${PROJECT_ROOT}/outputs"
    terraform output -json > "${PROJECT_ROOT}/outputs/deployment_${TIMESTAMP}.json"
    
    # Extract important values
    instance_ip=$(terraform output -raw instance_public_ip 2>/dev/null || echo "N/A")
    db_url=$(terraform output -raw autonomous_database_connection_urls 2>/dev/null || echo "N/A")
    
    # Create summary file
    cat > "${PROJECT_ROOT}/outputs/summary_${TIMESTAMP}.txt" << EOF
Deployment Summary (${TIMESTAMP})
===============================

Instance Public IP: ${instance_ip}
Database URL: ${db_url}

Access Instructions:
1. SSH to instance:
   ssh ubuntu@${instance_ip}

2. Database connection string is available in the wallet file

For full details, see:
- Terraform state: ${PROJECT_ROOT}/terraform.tfstate
- Outputs: ${PROJECT_ROOT}/outputs/deployment_${TIMESTAMP}.json
- Logs: ${LOG_FILE}
EOF

    log "Outputs saved successfully"
}

# Function to verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check instance
    instance_ip=$(terraform output -raw instance_public_ip 2>/dev/null)
    if [ -n "$instance_ip" ]; then
        if ping -c 1 "$instance_ip" >/dev/null 2>&1; then
            log "Instance is responsive at $instance_ip"
        else
            log "Warning: Instance at $instance_ip is not responding"
        fi
    fi
    
    # Check database
    db_id=$(terraform output -raw autonomous_database_id 2>/dev/null)
    if [ -n "$db_id" ]; then
        if oci db autonomous-database get --autonomous-database-id "$db_id" >/dev/null 2>&1; then
            log "Database is available"
        else
            log "Warning: Database verification failed"
        fi
    fi
    
    log "Deployment verification completed"
}

# Main function
main() {
    log "Starting Oracle infrastructure deployment..."
    
    # Run deployment steps
    check_oci_config || exit 1
    validate_env_vars || exit 1
    init_terraform || exit 1
    create_plan || exit 1
    apply_terraform || exit 1
    save_outputs || exit 1
    verify_deployment || exit 1
    
    log "Deployment completed successfully!"
    
    # Display summary
    if [ -f "${PROJECT_ROOT}/outputs/summary_${TIMESTAMP}.txt" ]; then
        echo
        cat "${PROJECT_ROOT}/outputs/summary_${TIMESTAMP}.txt"
    fi
}

# Run main function
main "$@"

