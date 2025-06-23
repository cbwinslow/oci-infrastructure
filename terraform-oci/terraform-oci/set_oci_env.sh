#!/bin/bash

# Script to set up OCI environment variables for Terraform
# Usage: source set_oci_env.sh

echo "Setting up OCI environment variables for Terraform..."

# Read values from terraform.tfvars
if [ -f "terraform.tfvars" ]; then
    # Extract values using grep and sed
    TENANCY_OCID=$(grep 'tenancy_ocid' terraform.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/')
    USER_OCID=$(grep 'user_ocid' terraform.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/')
    FINGERPRINT=$(grep 'fingerprint' terraform.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/')
    REGION=$(grep 'region' terraform.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/')
    
    # Export the environment variables
    export TF_VAR_tenancy_ocid="$TENANCY_OCID"
    export TF_VAR_user_ocid="$USER_OCID"
    export TF_VAR_fingerprint="$FINGERPRINT"
    export TF_VAR_region="$REGION"
    
    echo "Environment variables have been set:"
    echo "TF_VAR_tenancy_ocid=****(masked)****"
    echo "TF_VAR_user_ocid=****(masked)****"
    echo "TF_VAR_fingerprint=****(masked)****"
    echo "TF_VAR_region=$REGION"
else
    echo "Error: terraform.tfvars file not found!"
    return 1
fi

