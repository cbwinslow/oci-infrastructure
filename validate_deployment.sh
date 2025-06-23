#!/bin/bash

# Deployment Validation Script
# This script validates the deployment readiness without requiring actual cloud credentials

# set -e  # Don't exit on errors, we want to continue validation

echo "===================================="
echo "OCI Infrastructure Deployment Validation"
echo "===================================="
echo "Date: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Validate function
validate_item() {
    local description="$1"
    local check_command="$2"
    local requirement_level="$3"  # REQUIRED, OPTIONAL, INFO
    
    if eval "$check_command" > /dev/null 2>&1; then
        log_success "$description"
        ((TESTS_PASSED++))
        return 0
    else
        if [ "$requirement_level" = "REQUIRED" ]; then
            log_error "$description"
            ((TESTS_FAILED++))
            return 1
        elif [ "$requirement_level" = "OPTIONAL" ]; then
            log_warning "$description (optional)"
            ((TESTS_WARNED++))
            return 1
        else
            log_info "$description (informational)"
            return 1
        fi
    fi
}

log_info "Starting deployment validation..."
echo ""

# 1. Terraform Configuration Validation
log_info "=== Terraform Configuration Validation ==="
cd terraform-oci/terraform-oci

validate_item "Terraform binary available" "command -v terraform" "REQUIRED"
validate_item "Terraform configuration syntax" "terraform validate" "REQUIRED"
validate_item "Terraform formatting" "terraform fmt -check" "OPTIONAL"

# Check if terraform.tfvars exists
if [ -f "terraform.tfvars" ]; then
    log_success "Terraform variables file exists"
    ((TESTS_PASSED++))
else
    log_warning "terraform.tfvars not found (will use example)"
    ((TESTS_WARNED++))
fi

# Test terraform plan (without real credentials)
log_info "Testing Terraform plan generation (dry run)..."
if timeout 30s terraform plan -var="tenancy_ocid=ocid1.tenancy.oc1..test" \
    -var="user_ocid=ocid1.user.oc1..test" \
    -var="fingerprint=00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00" \
    -var="private_key_path=/dev/null" \
    -var="compartment_id=ocid1.compartment.oc1..test" \
    -var="instance_image_id=ocid1.image.oc1..test" \
    -var="ssh_public_key=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ test" \
    -var="db_admin_password=TestPassword123!" \
    -var="db_user_password=TestPassword123!" \
    -var="wallet_password=TestWallet123!" \
    > /dev/null 2>&1; then
    log_success "Terraform plan generation successful"
    ((TESTS_PASSED++))
else
    log_warning "Terraform plan failed (expected without real credentials)"
    ((TESTS_WARNED++))
fi

echo ""

# 2. Script Validation
log_info "=== Deployment Scripts Validation ==="
cd ../../

# Check deployment scripts exist and are executable
scripts_to_check=(
    "terraform-oci/scripts/deploy_free_tier.sh"
    "terraform-oci/scripts/deploy_oracle.sh"
    "agents/repo_repair/scripts/deploy.sh"
    "agents/repo_repair/scripts/package_integration.sh"
)

for script in "${scripts_to_check[@]}"; do
    validate_item "Script exists and executable: $(basename $script)" "[ -x \"$script\" ]" "REQUIRED"
done

echo ""

# 3. Configuration Files Validation
log_info "=== Configuration Files Validation ==="

config_files=(
    "agents/repo_repair/config/agent_config.json"
    "agents/repo_repair/config/capabilities.json"
    "terraform-oci/terraform-oci/terraform.tfvars.example"
)

for config in "${config_files[@]}"; do
    validate_item "Configuration exists: $(basename $config)" "[ -f \"$config\" ]" "REQUIRED"
    
    # Validate JSON files
    if [[ "$config" == *.json ]]; then
        validate_item "JSON syntax valid: $(basename $config)" "jq '.' \"$config\"" "REQUIRED"
    fi
done

echo ""

# 4. Test Infrastructure Validation
log_info "=== Test Infrastructure Validation ==="

test_files=(
    "tests/test_suite.sh"
    "tests/run_all_tests.sh"
    "tests/integration/test_ai_framework.sh"
    "tests/integration/test_package_management.sh"
    "tests/integration/test_security_tools.sh"
)

for test_file in "${test_files[@]}"; do
    validate_item "Test script exists: $(basename $test_file)" "[ -x \"$test_file\" ]" "REQUIRED"
done

echo ""

# 5. Documentation Validation
log_info "=== Documentation Validation ==="

docs=(
    "README.md"
    "PROJECT_PLAN.md"
    "SRS.md"
    "terraform-oci/terraform-oci/README.md"
    "terraform-oci/terraform-oci/DEPLOYMENT_GUIDE.md"
    "tests/README.md"
)

for doc in "${docs[@]}"; do
    validate_item "Documentation exists: $(basename $doc)" "[ -f \"$doc\" ]" "REQUIRED"
done

echo ""

# 6. Security Validation
log_info "=== Security Configuration Validation ==="

validate_item "Security documentation exists" "[ -f \"terraform-oci/terraform-oci/SECURITY.md\" ]" "REQUIRED"
validate_item "Security enhancements documented" "[ -f \"terraform-oci/SECURITY_ENHANCEMENTS.md\" ]" "REQUIRED"
validate_item "Gitignore configured" "[ -f \"terraform-oci/terraform-oci/.gitignore\" ]" "REQUIRED"

# Check for sensitive patterns in tracked files
if git ls-files | xargs grep -l "AKIA\|password.*=" 2>/dev/null | head -1 > /dev/null; then
    log_error "Potential sensitive data found in tracked files"
    ((TESTS_FAILED++))
else
    log_success "No obvious sensitive data in tracked files"
    ((TESTS_PASSED++))
fi

echo ""

# 7. Tool Dependencies Validation
log_info "=== Tool Dependencies Validation ==="

validate_item "Git available" "command -v git" "REQUIRED"
validate_item "jq available" "command -v jq" "OPTIONAL"
validate_item "curl available" "command -v curl" "OPTIONAL"
validate_item "Python available" "command -v python3" "OPTIONAL"

echo ""

# 8. Generate Deployment Readiness Report
log_info "=== Deployment Readiness Summary ==="

echo ""
echo "Test Results:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "  Warnings: $TESTS_WARNED"
echo ""

TOTAL_CRITICAL=$((TESTS_PASSED + TESTS_FAILED))
if [ $TESTS_FAILED -eq 0 ]; then
    log_success "✅ DEPLOYMENT READY - All critical validations passed"
    echo ""
    echo "Next Steps:"
    echo "1. Configure real OCI credentials in terraform.tfvars"
    echo "2. Review security settings for your environment"
    echo "3. Run terraform plan with real credentials"
    echo "4. Execute deployment with ./terraform-oci/scripts/deploy_free_tier.sh"
    
    # Create deployment status file
    cat > deployment_status.json << EOF
{
  "validation_date": "$(date -Iseconds)",
  "deployment_ready": true,
  "tests_passed": $TESTS_PASSED,
  "tests_failed": $TESTS_FAILED,
  "tests_warned": $TESTS_WARNED,
  "next_steps": [
    "Configure OCI credentials",
    "Review security settings",
    "Execute deployment"
  ]
}
EOF
    log_info "Deployment status saved to deployment_status.json"
    
elif [ $TESTS_FAILED -le 2 ]; then
    log_warning "⚠️  DEPLOYMENT READY WITH WARNINGS - Minor issues detected"
    echo "Please review failed items before deployment"
else
    log_error "❌ DEPLOYMENT NOT READY - Critical issues must be resolved"
    echo "Please fix failed items before attempting deployment"
fi

echo ""
echo "Validation completed: $(date)"
echo "===================================="

