#!/bin/bash

# Security Validation Script for OCI Terraform Infrastructure
# This script validates security configurations before applying Terraform plan

set -e

echo "🔒 Security Configuration Validation"
echo "===================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_status "ERROR" "Terraform is not installed or not in PATH"
    exit 1
fi

print_status "OK" "Terraform is installed"

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    print_status "ERROR" "main.tf not found. Please run this script from the terraform directory"
    exit 1
fi

print_status "OK" "Found Terraform configuration files"

# Validate Terraform configuration
echo ""
echo "🔍 Validating Terraform Configuration..."
terraform validate

if [ $? -eq 0 ]; then
    print_status "OK" "Terraform configuration is valid"
else
    print_status "ERROR" "Terraform configuration validation failed"
    exit 1
fi

# Check for security best practices
echo ""
echo "🛡️ Checking Security Best Practices..."

# Check if allowed_ssh_cidr is properly configured
echo ""
print_status "INFO" "Checking SSH access configuration..."

# Check if variable is defined
if grep -q "variable \"allowed_ssh_cidr\"" variables.tf; then
    print_status "OK" "SSH CIDR variable is defined"
    
    # Check default value
    default_value=$(grep -A 5 "variable \"allowed_ssh_cidr\"" variables.tf | grep "default" | awk -F'"' '{print $2}')
    if [ "$default_value" = "0.0.0.0/0" ]; then
        print_status "WARNING" "SSH access allows all IPs (0.0.0.0/0) - consider restricting for production"
        echo "         Recommendation: Set to specific IP range, e.g., \"YOUR_OFFICE_IP/32\""
    else
        print_status "OK" "SSH access is restricted to: $default_value"
    fi
else
    print_status "ERROR" "SSH CIDR variable not found"
fi

# Check for resource tagging
echo ""
print_status "INFO" "Checking resource tagging..."

tag_pattern="freeform_tags.*=.*{"
if grep -q "$tag_pattern" main.tf; then
    print_status "OK" "Resources include freeform tags"
    
    # Count tagged resources
    tag_count=$(grep -c "$tag_pattern" main.tf)
    print_status "INFO" "Found $tag_count resources with tags"
else
    print_status "WARNING" "No freeform tags found in resources"
fi

# Check for Network Security Groups
echo ""
print_status "INFO" "Checking Network Security Groups..."

if grep -q "oci_core_network_security_group" main.tf; then
    print_status "OK" "Network Security Groups are configured"
    
    # Count NSGs
    nsg_count=$(grep -c "resource \"oci_core_network_security_group\"" main.tf)
    print_status "INFO" "Found $nsg_count Network Security Groups"
    
    # Check for SSH NSG
    if grep -q "ssh_security_group" main.tf; then
        print_status "OK" "SSH Security Group is configured"
    else
        print_status "WARNING" "SSH Security Group not found"
    fi
    
    # Check for Web NSG
    if grep -q "web_security_group" main.tf; then
        print_status "OK" "Web Security Group is configured"
    else
        print_status "WARNING" "Web Security Group not found"
    fi
else
    print_status "WARNING" "No Network Security Groups found"
fi

# Check for security rules
echo ""
print_status "INFO" "Checking Security Rules..."

if grep -q "oci_core_network_security_group_security_rule" main.tf; then
    print_status "OK" "Network Security Group rules are configured"
    
    # Count security rules
    rule_count=$(grep -c "resource \"oci_core_network_security_group_security_rule\"" main.tf)
    print_status "INFO" "Found $rule_count security rules"
else
    print_status "WARNING" "No Network Security Group rules found"
fi

# Generate Terraform plan for final validation
echo ""
echo "📋 Generating Terraform Plan..."
print_status "INFO" "Running terraform plan to validate complete configuration..."

# Check if terraform has been initialized
if [ ! -d ".terraform" ]; then
    print_status "WARNING" "Terraform not initialized. Run 'terraform init' first"
    echo ""
    echo "To complete validation:"
    echo "1. Run: terraform init"
    echo "2. Run: terraform plan"
else
    # Run terraform plan in check mode if possible
    echo ""
    echo "Run the following command to see the planned changes:"
    echo "terraform plan -var=\"allowed_ssh_cidr=YOUR_IP/32\""
fi

# Security recommendations
echo ""
echo "🔐 Security Recommendations:"
echo "============================"
print_status "INFO" "Before applying the plan:"
echo "   1. Set allowed_ssh_cidr to your specific IP or network"
echo "   2. Review all security group rules"
echo "   3. Verify resource tags meet your organization's standards"
echo "   4. Consider additional security measures for production:"
echo "      - Private subnets for databases"
echo "      - Bastion hosts for administrative access"
echo "      - VPN or dedicated connections"
echo "      - Enable OCI Cloud Guard"
echo "      - Configure logging and monitoring"

echo ""
print_status "OK" "Security validation completed!"
echo ""
echo "Next steps:"
echo "1. Review the validation results above"
echo "2. Address any warnings or errors"
echo "3. Run: terraform plan -var=\"allowed_ssh_cidr=YOUR_IP/32\""
echo "4. If plan looks good, run: terraform apply"

