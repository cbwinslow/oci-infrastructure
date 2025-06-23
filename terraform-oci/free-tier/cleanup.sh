#!/bin/bash

# Script to destroy OCI Free Tier resources
echo "WARNING: This will destroy all resources created by Terraform!"
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

# Destroy resources
echo "Destroying resources..."
terraform destroy -auto-approve

# Clean up files
echo "Cleaning up files..."
rm -f terraform.tfplan outputs.json

echo "Cleanup completed!"

