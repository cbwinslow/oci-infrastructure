#!/bin/bash

# Cleanup script for OCI Free Tier Infrastructure

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="${PROJECT_ROOT}/free-tier"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/cleanup_$(date +%Y%m%d_%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Confirm cleanup
confirm_cleanup() {
    echo "WARNING: This will destroy all resources created in the Free Tier deployment!"
    echo "The following resources will be destroyed:"
    echo "- Compute Instance"
    echo "- Autonomous Database"
    echo "- Block Volume"
    echo "- Virtual Cloud Network"
    echo "- All associated networking resources"
    echo
    read -p "Are you sure you want to proceed? (yes/no) " answer
    if [[ "$answer" != "yes" ]]; then
        log "Cleanup cancelled by user"
        exit 0
    fi
}

# Cleanup Terraform resources
cleanup_terraform() {
    log "Starting Terraform cleanup..."
    cd "$TERRAFORM_DIR"
    
    # Destroy Terraform resources
    log "Destroying Terraform-managed resources..."
    terraform destroy -auto-approve 2>&1 | tee -a "$LOG_FILE"
    
    # Clean up Terraform files
    log "Cleaning up Terraform files..."
    rm -f terraform.tfstate*
    rm -f .terraform.lock.hcl
    rm -rf .terraform/
    rm -f tfplan
}

# Cleanup local files
cleanup_local_files() {
    log "Cleaning up local files..."
    
    # Save the current log file
    local current_log="$LOG_FILE"
    
    # Clean up old log files (keep last 5)
    cd "$LOG_DIR"
    ls -t | grep -v $(basename "$current_log") | tail -n +6 | xargs -r rm
    
    # Clean up wallet and other sensitive files
    rm -f wallet.zip
    rm -f connection_info.txt
    
    log "Local cleanup completed"
}

# Main cleanup function
main() {
    log "Starting cleanup of OCI Free Tier infrastructure..."
    
    confirm_cleanup
    cleanup_terraform
    cleanup_local_files
    
    log "Cleanup completed successfully!"
    
    # Create cleanup summary
    cat > "${LOG_DIR}/cleanup_summary.txt" << EOF
OCI Free Tier Infrastructure Cleanup Summary
=========================================

The following resources have been destroyed:
- Compute Instance
- Autonomous Database
- Block Volume
- Virtual Cloud Network
- All associated networking resources

All local configuration files and terraform state have been cleaned up.
Logs are preserved in: ${LOG_DIR}

Cleanup completed at: $(date)
EOF
    
    cat "${LOG_DIR}/cleanup_summary.txt"
}

# Error handling
set -e
trap 'echo "Error occurred on line $LINENO. Check log for details."' ERR

# Run main function
main "$@"

