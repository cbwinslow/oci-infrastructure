#!/bin/bash

# Script to deploy OCI Free Tier resources
echo "Deploying OCI Free Tier resources..."

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create plan file
echo "Creating Terraform plan..."
terraform plan -out=terraform.tfplan

# Apply the configuration
echo "Applying Terraform configuration..."
terraform apply "terraform.tfplan"

# Save outputs
echo "Saving outputs to outputs.json..."
terraform output -json > outputs.json

echo "Deployment completed!"
echo "Check outputs.json for connection details"

