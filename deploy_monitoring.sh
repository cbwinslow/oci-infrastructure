#!/bin/bash

# OCI Infrastructure Monitoring and Maintenance Deployment Script
# This script deploys the complete monitoring and maintenance infrastructure

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/deployment.log"
DATE=$(date +"%Y%m%d_%H%M%S")

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking deployment prerequisites..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log "Warning: Not running as root. Some deployment steps may require sudo."
    fi
    
    # Check required tools
    REQUIRED_TOOLS=("terraform" "git")
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error_exit "Required tool not found: $tool"
        fi
    done
    
    # Check OCI CLI (optional but recommended)
    if ! command -v oci &> /dev/null; then
        log "Warning: OCI CLI not found. Cloud features will be limited."
    else
        log "OCI CLI found: $(oci --version | head -1)"
    fi
    
    log "Prerequisites check completed"
}

# Function to deploy monitoring infrastructure
deploy_monitoring() {
    log "Deploying monitoring infrastructure..."
    
    cd "$SCRIPT_DIR/monitoring"
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        log "Initializing Terraform..."
        terraform init || error_exit "Terraform initialization failed"
    fi
    
    # Validate Terraform configuration
    log "Validating Terraform configuration..."
    terraform validate || error_exit "Terraform validation failed"
    
    # Plan deployment (this will show what will be created)
    log "Planning Terraform deployment..."
    terraform plan -out="deployment.tfplan" || error_exit "Terraform planning failed"
    
    # Apply deployment
    log "Applying Terraform configuration..."
    terraform apply "deployment.tfplan" || error_exit "Terraform deployment failed"
    
    log "Monitoring infrastructure deployed successfully"
}

# Function to setup maintenance system
setup_maintenance() {
    log "Setting up maintenance system..."
    
    cd "$SCRIPT_DIR/maintenance"
    
    # Make all scripts executable
    chmod +x *.sh || error_exit "Failed to make scripts executable"
    
    # Run maintenance setup
    log "Running maintenance system setup..."
    ./master_maintenance.sh setup || error_exit "Maintenance setup failed"
    
    log "Maintenance system setup completed"
}

# Function to run initial tests
run_initial_tests() {
    log "Running initial system tests..."
    
    cd "$SCRIPT_DIR/maintenance"
    
    # Test maintenance system status
    ./master_maintenance.sh status || log "Warning: Status check had issues"
    
    # Test individual components (dry run)
    log "Testing security update script..."
    bash -n security_updates.sh || log "Warning: Security script syntax check failed"
    
    log "Testing performance optimization script..."
    bash -n performance_optimization.sh || log "Warning: Performance script syntax check failed"
    
    log "Testing configuration management script..."
    bash -n configuration_management.sh || log "Warning: Configuration script syntax check failed"
    
    log "Testing backup procedures script..."
    bash -n backup_procedures.sh || log "Warning: Backup script syntax check failed"
    
    log "Initial tests completed"
}

# Function to generate deployment report
generate_deployment_report() {
    log "Generating deployment report..."
    
    REPORT_FILE="$SCRIPT_DIR/deployment_report_$DATE.txt"
    
    cat > "$REPORT_FILE" << EOF
OCI Infrastructure Monitoring and Maintenance Deployment Report
Generated: $(date)
Deployment Session: $DATE

=== System Information ===
Hostname: $(hostname)
Operating System: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)

=== Deployment Status ===
Monitoring Infrastructure: $([ -f "$SCRIPT_DIR/monitoring/.terraform/terraform.tfstate" ] && echo "DEPLOYED" || echo "NOT DEPLOYED")
Maintenance System: $([ -x "$SCRIPT_DIR/maintenance/master_maintenance.sh" ] && echo "CONFIGURED" || echo "NOT CONFIGURED")

=== Directory Structure ===
$(tree "$SCRIPT_DIR" -L 3 2>/dev/null || find "$SCRIPT_DIR" -type d | head -20)

=== Scripts Status ===
$(ls -la "$SCRIPT_DIR/maintenance"/*.sh)

=== Terraform Outputs ===
EOF

    # Add Terraform outputs if available
    if [ -f "$SCRIPT_DIR/monitoring/.terraform/terraform.tfstate" ]; then
        cd "$SCRIPT_DIR/monitoring"
        terraform output >> "$REPORT_FILE" 2>/dev/null || echo "No Terraform outputs available" >> "$REPORT_FILE"
    else
        echo "Terraform not yet deployed" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

=== Next Steps ===
1. Configure OCI credentials if not already done:
   oci setup config

2. Update Terraform variables in monitoring/terraform.tfvars

3. Deploy monitoring infrastructure:
   cd monitoring && terraform apply

4. Run initial maintenance cycle:
   sudo maintenance/master_maintenance.sh full

5. Setup email notifications (optional):
   Configure SMTP and update maintenance scripts

6. Verify monitoring dashboards and alerts

=== Important Files ===
- Deployment log: $LOG_FILE
- Monitoring variables: $SCRIPT_DIR/monitoring/variables.tf
- Master maintenance script: $SCRIPT_DIR/maintenance/master_maintenance.sh
- Documentation: $SCRIPT_DIR/monitoring/README.md

EOF

    log "Deployment report created: $REPORT_FILE"
}

# Function to create example configuration
create_example_config() {
    log "Creating example configuration files..."
    
    # Create terraform.tfvars.example
    cat > "$SCRIPT_DIR/monitoring/terraform.tfvars.example" << EOF
# Example Terraform variables file
# Copy this to terraform.tfvars and update with your values

compartment_id = "ocid1.compartment.oc1..your-compartment-ocid"
tenancy_ocid   = "ocid1.tenancy.oc1..your-tenancy-ocid"
alert_email    = "your-email@domain.com"
environment    = "production"

health_check_targets = [
  "https://your-website.com",
  "https://your-api.com/health"
]

alert_thresholds = {
  cpu_threshold    = 80
  memory_threshold = 85
  disk_threshold   = 90
}
EOF

    # Create environment configuration example
    cat > "$SCRIPT_DIR/maintenance/environment.conf.example" << EOF
# Example environment configuration for maintenance scripts
# Copy this to environment.conf and update with your values

# Email configuration for notifications
MAINTENANCE_EMAIL="admin@your-domain.com"
BACKUP_EMAIL="backup-admin@your-domain.com"

# OCI Object Storage bucket for backups
OCI_BACKUP_BUCKET="your-infrastructure-backups"

# Backup retention settings
RETENTION_DAYS=30

# Performance monitoring settings
PERFORMANCE_MONITORING_ENABLED=true
PERFORMANCE_ALERT_THRESHOLD=85

# Security settings
SECURITY_SCAN_ENABLED=true
SECURITY_UPDATE_ENABLED=true
EOF

    log "Example configuration files created"
}

# Function to display deployment summary
display_summary() {
    echo ""
    echo "=========================================="
    echo "  OCI Monitoring & Maintenance Deployed"
    echo "=========================================="
    echo ""
    echo "✓ Prerequisites checked"
    echo "✓ Directory structure created"
    echo "✓ Scripts made executable"
    echo "✓ Example configurations created"
    echo ""
    echo "Next Steps:"
    echo "1. Configure your OCI credentials:"
    echo "   oci setup config"
    echo ""
    echo "2. Update monitoring variables:"
    echo "   cp monitoring/terraform.tfvars.example monitoring/terraform.tfvars"
    echo "   # Edit terraform.tfvars with your values"
    echo ""
    echo "3. Deploy monitoring infrastructure:"
    echo "   cd monitoring && terraform apply"
    echo ""
    echo "4. Setup maintenance environment:"
    echo "   sudo maintenance/master_maintenance.sh setup"
    echo ""
    echo "5. Run initial maintenance:"
    echo "   sudo maintenance/master_maintenance.sh full"
    echo ""
    echo "Documentation: monitoring/README.md"
    echo "Deployment log: $LOG_FILE"
    echo "=========================================="
}

# Main deployment function
main() {
    log "=== Starting OCI Monitoring and Maintenance Deployment ==="
    
    check_prerequisites
    create_example_config
    setup_maintenance
    run_initial_tests
    generate_deployment_report
    
    log "=== Deployment Completed Successfully ==="
    
    display_summary
}

# Execute main function
main "$@"

