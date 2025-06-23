# OCI Infrastructure Terraform Configuration

This repository contains Terraform configurations for managing OCI infrastructure.

## Credential Setup

1. Copy `terraform.tfvars.example` to `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your OCI credentials:
   - region: Your OCI region (e.g., "us-ashburn-1")
   - tenancy_ocid: Your tenancy OCID from OCI Console
   - user_ocid: Your user OCID from OCI Console
   - fingerprint: Your API key fingerprint
   - private_key_path: Path to your OCI API private key

3. Ensure your OCI API private key:
   - Is located at `~/.oci/oci_api_key.pem`
   - Has secure permissions (600)
   ```bash
   chmod 600 ~/.oci/oci_api_key.pem
   ```

## Security Notes

- Keep `terraform.tfvars` secure and never commit it to version control
- The `.gitignore` file is configured to exclude sensitive files
- Consider using environment variables or a secure secrets manager for production deployments

