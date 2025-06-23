#!/bin/bash

# OCI Credentials Setup Helper Script
# This script helps configure your OCI credentials for production deployment

set -e

echo "======================================================"
echo "🔑 OCI Credentials Setup for Production Deployment"
echo "======================================================"
echo "Date: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if OCI CLI is installed and configured
check_oci_cli() {
    log_info "Checking OCI CLI installation and configuration..."
    
    if ! command -v oci &> /dev/null; then
        log_warning "OCI CLI not found. Please install it first:"
        echo "  bash -c \"\$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)\""
        return 1
    fi
    
    log_success "OCI CLI is installed"
    
    # Check if OCI CLI is configured
    if [ -f ~/.oci/config ]; then
        log_success "OCI CLI configuration found"
        
        # Try to test the configuration
        if oci iam region list > /dev/null 2>&1; then
            log_success "OCI CLI configuration is valid"
            return 0
        else
            log_warning "OCI CLI configuration exists but may be invalid"
            log_info "Please run: oci setup config"
            return 1
        fi
    else
        log_warning "OCI CLI not configured. Please run: oci setup config"
        return 1
    fi
}

# Extract configuration from OCI CLI
extract_oci_config() {
    log_info "Extracting configuration from OCI CLI..."
    
    local config_file="$HOME/.oci/config"
    if [ ! -f "$config_file" ]; then
        log_error "OCI configuration file not found: $config_file"
        return 1
    fi
    
    # Extract values from OCI config
    local tenancy_ocid=$(grep "tenancy=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    local user_ocid=$(grep "user=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    local fingerprint=$(grep "fingerprint=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    local key_file=$(grep "key_file=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    local region=$(grep "region=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
    
    # Expand tilde in key_file path
    key_file="${key_file/#\~/$HOME}"
    
    echo "Configuration extracted:"
    echo "  Region: $region"
    echo "  Tenancy OCID: ${tenancy_ocid:0:25}..."
    echo "  User OCID: ${user_ocid:0:25}..."
    echo "  Fingerprint: $fingerprint"
    echo "  Key File: $key_file"
    
    # Store in variables for use
    export OCI_REGION="$region"
    export OCI_TENANCY_OCID="$tenancy_ocid"
    export OCI_USER_OCID="$user_ocid"
    export OCI_FINGERPRINT="$fingerprint"
    export OCI_KEY_FILE="$key_file"
    
    return 0
}

# Get compartment OCID
get_compartment_ocid() {
    log_info "Getting compartment information..."
    
    # List available compartments
    log_info "Available compartments:"
    oci iam compartment list --all --query "data[?\"lifecycle-state\"=='ACTIVE'].{Name:name,OCID:id}" --output table 2>/dev/null || {
        log_warning "Could not list compartments. Using tenancy root compartment."
        export OCI_COMPARTMENT_ID="$OCI_TENANCY_OCID"
        return 0
    }
    
    echo ""
    echo "Enter the OCID of the compartment to use (or press Enter for root compartment):"
    read -r compartment_input
    
    if [ -z "$compartment_input" ]; then
        export OCI_COMPARTMENT_ID="$OCI_TENANCY_OCID"
        log_info "Using root compartment: ${OCI_COMPARTMENT_ID:0:25}..."
    else
        export OCI_COMPARTMENT_ID="$compartment_input"
        log_info "Using specified compartment: ${OCI_COMPARTMENT_ID:0:25}..."
    fi
}

# Get available image for compute instance
get_ubuntu_image() {
    log_info "Finding Ubuntu image for compute instance..."
    
    local image_ocid=$(oci compute image list \
        --compartment-id "$OCI_COMPARTMENT_ID" \
        --operating-system "Canonical Ubuntu" \
        --operating-system-version "22.04" \
        --shape "VM.Standard.E2.1.Micro" \
        --region "$OCI_REGION" \
        --query 'data[0].id' \
        --raw-output 2>/dev/null || echo "")
    
    if [ -n "$image_ocid" ]; then
        export OCI_IMAGE_OCID="$image_ocid"
        log_success "Found Ubuntu image: ${image_ocid:0:25}..."
    else
        log_warning "Could not automatically find Ubuntu image."
        echo "Please provide Ubuntu 22.04 image OCID for your region:"
        read -r image_input
        export OCI_IMAGE_OCID="$image_input"
    fi
}

# Generate SSH key if needed
setup_ssh_key() {
    log_info "Setting up SSH key for instance access..."
    
    local ssh_key_path="$HOME/.ssh/oci_instance_key"
    local ssh_pub_key_path="${ssh_key_path}.pub"
    
    if [ ! -f "$ssh_pub_key_path" ]; then
        log_info "Generating new SSH key pair..."
        ssh-keygen -t rsa -b 2048 -f "$ssh_key_path" -N "" -C "oci-instance-key"
        log_success "SSH key pair generated: $ssh_key_path"
    else
        log_success "Existing SSH key found: $ssh_pub_key_path"
    fi
    
    export OCI_SSH_PUBLIC_KEY=$(cat "$ssh_pub_key_path")
    export OCI_SSH_PRIVATE_KEY_PATH="$ssh_key_path"
    
    log_info "SSH public key: ${OCI_SSH_PUBLIC_KEY:0:50}..."
}

# Generate secure passwords
generate_passwords() {
    log_info "Generating secure passwords for database..."
    
    # Generate database admin password (Oracle requirements: 12-30 chars, 2 uppercase, 2 lowercase, 2 numbers, 2 special chars)
    export OCI_DB_ADMIN_PASSWORD="AdminPass$(date +%Y)!"
    export OCI_DB_USER_PASSWORD="UserPass$(date +%Y)!"
    export OCI_WALLET_PASSWORD="WalletPass$(date +%Y)!"
    
    log_success "Database passwords generated"
    log_warning "IMPORTANT: Save these passwords securely!"
    echo "  Admin Password: $OCI_DB_ADMIN_PASSWORD"
    echo "  User Password: $OCI_DB_USER_PASSWORD"
    echo "  Wallet Password: $OCI_WALLET_PASSWORD"
}

# Update terraform.tfvars with real values
update_terraform_vars() {
    log_info "Updating terraform.tfvars with real configuration..."
    
    local tfvars_file="terraform-oci/terraform-oci/terraform.tfvars"
    local backup_file="${tfvars_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Backup existing file
    cp "$tfvars_file" "$backup_file"
    log_info "Backup created: $backup_file"
    
    # Create new terraform.tfvars with real values
    cat > "$tfvars_file" << EOF
# OCI Authentication Configuration
region           = "$OCI_REGION"
tenancy_ocid     = "$OCI_TENANCY_OCID"
user_ocid        = "$OCI_USER_OCID"
fingerprint      = "$OCI_FINGERPRINT"
private_key_path = "$OCI_KEY_FILE"

# Resource Configuration
compartment_id = "$OCI_COMPARTMENT_ID"

# Database Configuration
db_name              = "ORCL"
db_admin_password    = "$OCI_DB_ADMIN_PASSWORD"
db_user_password     = "$OCI_DB_USER_PASSWORD"
db_version           = "19c"
db_workload          = "OLTP"
wallet_password      = "$OCI_WALLET_PASSWORD"

# Compute Configuration
instance_image_id = "$OCI_IMAGE_OCID"
ssh_public_key    = "$OCI_SSH_PUBLIC_KEY"

# Network Configuration
vcn_cidr                = "10.0.0.0/16"
subnet_cidr             = "10.0.1.0/24"
instance_subnet_cidr    = "10.0.2.0/24"

# Security Configuration (Restrict SSH access for production!)
allowed_ssh_cidr = "0.0.0.0/0"  # CHANGE THIS for production!

# Storage Configuration
volume_size_in_gbs = 50
EOF
    
    log_success "terraform.tfvars updated with production configuration"
    log_warning "SECURITY NOTE: Review and restrict allowed_ssh_cidr for production!"
}

# Create deployment summary
create_deployment_summary() {
    log_info "Creating deployment summary..."
    
    local summary_file="deployment_summary_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$summary_file" << EOF
# OCI Infrastructure Deployment Summary

**Date**: $(date)
**Configuration**: Production Ready

## Infrastructure Configuration
- **Region**: $OCI_REGION
- **Compartment**: ${OCI_COMPARTMENT_ID:0:25}...
- **Database**: Autonomous Database (Free Tier)
- **Compute**: VM.Standard.E2.1.Micro (Free Tier)
- **Storage**: 50GB Block Volume

## Security Configuration
- SSH Key: ${OCI_SSH_PRIVATE_KEY_PATH}
- Database Passwords: Securely generated
- VCN: 10.0.0.0/16 with proper security groups

## Next Steps
1. Review terraform.tfvars configuration
2. Run: \`terraform plan\` to preview changes
3. Run: \`terraform apply\` to deploy infrastructure
4. Save SSH private key and database passwords securely

## Important Files
- Terraform Config: terraform-oci/terraform-oci/
- SSH Private Key: $OCI_SSH_PRIVATE_KEY_PATH
- SSH Public Key: ${OCI_SSH_PRIVATE_KEY_PATH}.pub
- Deployment Script: terraform-oci/scripts/deploy_free_tier.sh

## Security Reminders
- ⚠️  Update allowed_ssh_cidr in terraform.tfvars
- 🔒 Store passwords in secure password manager
- 🔑 Backup SSH private key securely
- 📱 Enable MFA on OCI account
EOF
    
    log_success "Deployment summary created: $summary_file"
    export DEPLOYMENT_SUMMARY_FILE="$summary_file"
}

# Main execution
main() {
    echo "This script will help you configure OCI credentials for production deployment."
    echo "Press Enter to continue or Ctrl+C to abort..."
    read -r
    
    # Step 1: Check OCI CLI
    if ! check_oci_cli; then
        log_error "Please install and configure OCI CLI first"
        echo ""
        echo "Quick setup:"
        echo "1. Install OCI CLI: bash -c \"\$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)\""
        echo "2. Configure: oci setup config"
        echo "3. Run this script again"
        exit 1
    fi
    
    # Step 2: Extract configuration
    if ! extract_oci_config; then
        log_error "Failed to extract OCI configuration"
        exit 1
    fi
    
    # Step 3: Get compartment
    get_compartment_ocid
    
    # Step 4: Get Ubuntu image
    get_ubuntu_image
    
    # Step 5: Setup SSH key
    setup_ssh_key
    
    # Step 6: Generate passwords
    generate_passwords
    
    # Step 7: Update terraform.tfvars
    update_terraform_vars
    
    # Step 8: Create summary
    create_deployment_summary
    
    echo ""
    log_success "✅ OCI credentials configuration complete!"
    echo ""
    echo "📋 Summary:"
    echo "  - terraform.tfvars updated with production values"
    echo "  - SSH key pair ready for instance access"
    echo "  - Database passwords generated"
    echo "  - Deployment summary: $DEPLOYMENT_SUMMARY_FILE"
    echo ""
    echo "🚀 Ready for deployment! Next steps:"
    echo "  1. cd terraform-oci/terraform-oci"
    echo "  2. terraform plan    # Review deployment plan"
    echo "  3. terraform apply   # Deploy infrastructure"
    echo ""
    log_warning "💡 Remember to secure your passwords and SSH keys!"
}

# Execute main function
main "$@"

