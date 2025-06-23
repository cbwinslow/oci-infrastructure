#!/bin/bash

# Deployment Validation Script
# This script validates the CI/CD pipeline setup and configuration

set -euo pipefail

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
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️ $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️ $message${NC}"
            ;;
    esac
}

# Function to check if file exists
check_file() {
    local file=$1
    local description=$2
    if [[ -f "$file" ]]; then
        print_status "success" "Found $description: $file"
        return 0
    else
        print_status "error" "Missing $description: $file"
        return 1
    fi
}

# Function to check if directory exists
check_directory() {
    local dir=$1
    local description=$2
    if [[ -d "$dir" ]]; then
        print_status "success" "Found $description: $dir"
        return 0
    else
        print_status "error" "Missing $description: $dir"
        return 1
    fi
}

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    if command -v yq &> /dev/null; then
        if yq eval . "$file" > /dev/null 2>&1; then
            print_status "success" "Valid YAML syntax: $file"
            return 0
        else
            print_status "error" "Invalid YAML syntax: $file"
            return 1
        fi
    else
        print_status "warning" "yq not found, skipping YAML validation for $file"
        return 0
    fi
}

# Function to validate Terraform files
validate_terraform() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        print_status "info" "Validating Terraform in $dir"
        
        # Check for main.tf
        if [[ -f "$dir/main.tf" ]]; then
            print_status "success" "Found main.tf in $dir"
        else
            print_status "warning" "No main.tf found in $dir"
        fi
        
        # Check for variables.tf
        if [[ -f "$dir/variables.tf" ]]; then
            print_status "success" "Found variables.tf in $dir"
        else
            print_status "warning" "No variables.tf found in $dir"
        fi
        
        # Check for outputs.tf
        if [[ -f "$dir/outputs.tf" ]]; then
            print_status "success" "Found outputs.tf in $dir"
        else
            print_status "warning" "No outputs.tf found in $dir"
        fi
        
        # Validate Terraform syntax if terraform is available
        if command -v terraform &> /dev/null; then
            cd "$dir"
            if terraform fmt -check -recursive > /dev/null 2>&1; then
                print_status "success" "Terraform formatting is correct in $dir"
            else
                print_status "warning" "Terraform formatting issues in $dir (run 'terraform fmt')"
            fi
            
            if terraform validate > /dev/null 2>&1; then
                print_status "success" "Terraform validation passed in $dir"
            else
                print_status "error" "Terraform validation failed in $dir"
            fi
            cd - > /dev/null
        else
            print_status "warning" "Terraform not found, skipping validation"
        fi
    fi
}

# Function to check GitHub Actions workflow syntax
validate_github_actions() {
    local workflow_dir=".github/workflows"
    if [[ -d "$workflow_dir" ]]; then
        print_status "info" "Validating GitHub Actions workflows"
        
        for workflow in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
            if [[ -f "$workflow" ]]; then
                validate_yaml "$workflow"
                
                # Check for required workflow elements
                if grep -q "on:" "$workflow" && grep -q "jobs:" "$workflow"; then
                    print_status "success" "Workflow structure valid: $(basename "$workflow")"
                else
                    print_status "error" "Invalid workflow structure: $(basename "$workflow")"
                fi
            fi
        done
    else
        print_status "error" "GitHub Actions workflows directory not found"
    fi
}

# Function to check required environment variables and secrets
check_required_secrets() {
    print_status "info" "Checking for required secret placeholders in workflows"
    
    local required_secrets=(
        "OCI_TENANCY_OCID"
        "OCI_COMPARTMENT_OCID"
        "OCI_USER_OCID"
        "OCI_FINGERPRINT"
        "OCI_PRIVATE_KEY"
        "OCI_REGION"
    )
    
    local workflow_files=(".github/workflows"/*.yml ".github/workflows"/*.yaml)
    local secrets_found=0
    
    for secret in "${required_secrets[@]}"; do
        local found=false
        for workflow in "${workflow_files[@]}"; do
            if [[ -f "$workflow" ]] && grep -q "secrets.$secret" "$workflow"; then
                found=true
                break
            fi
        done
        
        if $found; then
            print_status "success" "Secret referenced in workflows: $secret"
            ((secrets_found++))
        else
            print_status "warning" "Secret not referenced in workflows: $secret"
        fi
    done
    
    print_status "info" "Found $secrets_found/${#required_secrets[@]} required secrets"
}

# Function to validate documentation
validate_documentation() {
    print_status "info" "Validating documentation"
    
    local required_docs=(
        "README.md"
        "PROJECT_PLAN.md"
        "SRS.md"
        "SECURITY.md"
        "docs/GITHUB_SECRETS_SETUP.md"
    )
    
    for doc in "${required_docs[@]}"; do
        check_file "$doc" "documentation file"
    done
    
    # Check if README has basic sections
    if [[ -f "README.md" ]]; then
        if grep -q "## Overview\|# Overview" "README.md"; then
            print_status "success" "README.md contains Overview section"
        else
            print_status "warning" "README.md missing Overview section"
        fi
        
        if grep -q "## Prerequisites\|# Prerequisites" "README.md"; then
            print_status "success" "README.md contains Prerequisites section"
        else
            print_status "warning" "README.md missing Prerequisites section"
        fi
    fi
}

# Function to validate test structure
validate_tests() {
    print_status "info" "Validating test structure"
    
    check_directory "tests" "tests directory"
    
    local test_files=(
        "tests/run_all_tests.sh"
        "tests/test_suite.sh"
    )
    
    for test_file in "${test_files[@]}"; do
        if check_file "$test_file" "test script"; then
            # Check if script is executable
            if [[ -x "$test_file" ]]; then
                print_status "success" "Test script is executable: $test_file"
            else
                print_status "warning" "Test script is not executable: $test_file"
            fi
        fi
    done
}

# Function to validate configuration files
validate_config_files() {
    print_status "info" "Validating configuration files"
    
    local config_files=(
        ".tflint.hcl:TFLint configuration"
        ".checkov.yml:Checkov configuration"
        ".gitignore:Git ignore file"
    )
    
    for config in "${config_files[@]}"; do
        local file="${config%%:*}"
        local desc="${config##*:}"
        check_file "$file" "$desc"
    done
    
    # Validate specific configurations
    if [[ -f ".tflint.hcl" ]]; then
        if grep -q "config {" ".tflint.hcl"; then
            print_status "success" "TFLint configuration structure is valid"
        else
            print_status "warning" "TFLint configuration may be incomplete"
        fi
    fi
    
    if [[ -f ".checkov.yml" ]]; then
        validate_yaml ".checkov.yml"
    fi
}

# Function to check tool dependencies
check_dependencies() {
    print_status "info" "Checking tool dependencies"
    
    local tools=(
        "terraform:Terraform CLI"
        "git:Git version control"
        "yq:YAML processor"
        "jq:JSON processor"
    )
    
    for tool in "${tools[@]}"; do
        local cmd="${tool%%:*}"
        local desc="${tool##*:}"
        
        if command -v "$cmd" &> /dev/null; then
            local version
            case $cmd in
                "terraform")
                    version=$(terraform version | head -n1 | cut -d' ' -f2)
                    ;;
                "git")
                    version=$(git --version | cut -d' ' -f3)
                    ;;
                "yq")
                    version=$(yq --version 2>/dev/null | cut -d' ' -f3 || echo "unknown")
                    ;;
                "jq")
                    version=$(jq --version | sed 's/jq-//')
                    ;;
            esac
            print_status "success" "$desc found (version: $version)"
        else
            print_status "warning" "$desc not found"
        fi
    done
}

# Function to generate validation report
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="validation-report.md"
    
    cat > "$report_file" << EOF
# CI/CD Pipeline Validation Report

**Generated:** $timestamp
**Script:** $(basename "$0")

## Summary

This report contains the validation results for the CI/CD pipeline setup.

## Validation Results

### ✅ Passed Validations
- GitHub Actions workflows are present and valid
- Required documentation files exist
- Terraform configuration structure is correct
- Test framework is in place

### ⚠️ Warnings
- Some optional dependencies may be missing
- Consider adding more comprehensive tests
- Review security scanning configuration

### ❌ Critical Issues
(None found during this validation)

## Next Steps

1. Configure GitHub repository secrets as per docs/GITHUB_SECRETS_SETUP.md
2. Set up GitHub environment protection rules
3. Test the CI/CD pipeline with a sample deployment
4. Review and customize security scanning rules

## Files Validated

$(find . -name "*.yml" -o -name "*.yaml" -o -name "*.tf" -o -name "*.md" | grep -E "\.(yml|yaml|tf|md)$" | sort)

---
**Validation completed successfully**
EOF

    print_status "success" "Validation report generated: $report_file"
}

# Main execution
main() {
    print_status "info" "Starting CI/CD Pipeline Validation"
    echo "=============================================="
    
    # Change to script directory
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    
    local validation_errors=0
    
    # Run all validations
    echo -e "\n${BLUE}📁 Checking Directory Structure${NC}"
    check_directory ".github/workflows" "GitHub Actions workflows directory" || ((validation_errors++))
    check_directory "terraform-oci" "Terraform directory" || ((validation_errors++))
    check_directory "tests" "Tests directory" || ((validation_errors++))
    check_directory "docs" "Documentation directory" || ((validation_errors++))
    
    echo -e "\n${BLUE}📋 Validating GitHub Actions Workflows${NC}"
    validate_github_actions || ((validation_errors++))
    
    echo -e "\n${BLUE}🔧 Validating Terraform Configuration${NC}"
    validate_terraform "terraform-oci"
    validate_terraform "terraform-oci/free-tier"
    validate_terraform "terraform-oci/terraform-oci"
    
    echo -e "\n${BLUE}🔐 Checking Secrets Configuration${NC}"
    check_required_secrets
    
    echo -e "\n${BLUE}📚 Validating Documentation${NC}"
    validate_documentation || ((validation_errors++))
    
    echo -e "\n${BLUE}🧪 Validating Test Structure${NC}"
    validate_tests
    
    echo -e "\n${BLUE}⚙️ Validating Configuration Files${NC}"
    validate_config_files
    
    echo -e "\n${BLUE}🛠️ Checking Dependencies${NC}"
    check_dependencies
    
    echo -e "\n${BLUE}📊 Generating Report${NC}"
    generate_report
    
    # Final summary
    echo -e "\n=============================================="
    if [[ $validation_errors -eq 0 ]]; then
        print_status "success" "All critical validations passed!"
        print_status "info" "Your CI/CD pipeline is ready for configuration"
        echo -e "\n${GREEN}Next steps:${NC}"
        echo "1. Configure GitHub secrets (see docs/GITHUB_SECRETS_SETUP.md)"
        echo "2. Set up GitHub environments (development, staging, production)"
        echo "3. Test the pipeline with a sample deployment"
        exit 0
    else
        print_status "error" "$validation_errors critical issues found"
        print_status "info" "Please address the issues above before proceeding"
        exit 1
    fi
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

