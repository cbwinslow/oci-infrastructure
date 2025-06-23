# GitHub Secrets Configuration Guide

This document provides comprehensive instructions for configuring GitHub repository and environment secrets required for the CI/CD pipeline.

## Table of Contents

- [Overview](#overview)
- [Repository Secrets](#repository-secrets)
- [Environment Secrets](#environment-secrets)
- [OCI Credentials Setup](#oci-credentials-setup)
- [Service Account Configuration](#service-account-configuration)
- [API Tokens](#api-tokens)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

Our CI/CD pipeline requires several types of secrets:

1. **OCI (Oracle Cloud Infrastructure) Credentials** - For Terraform authentication
2. **API Tokens** - For external service integrations
3. **Service Account Keys** - For service-to-service authentication
4. **Environment-specific secrets** - For different deployment environments

## Repository Secrets

Repository secrets are available to all workflows in the repository. Configure these secrets in GitHub:

**Navigate to:** Repository → Settings → Secrets and variables → Actions → Repository secrets

### Required OCI Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `OCI_TENANCY_OCID` | Your OCI tenancy OCID | `ocid1.tenancy.oc1..aaaaa...` |
| `OCI_COMPARTMENT_OCID` | Target compartment OCID | `ocid1.compartment.oc1..aaaaa...` |
| `OCI_USER_OCID` | OCI user OCID for API access | `ocid1.user.oc1..aaaaa...` |
| `OCI_FINGERPRINT` | API key fingerprint | `aa:bb:cc:dd:ee:ff:gg:hh:ii:jj:kk:ll:mm:nn:oo:pp` |
| `OCI_PRIVATE_KEY` | Private key content (PEM format) | `-----BEGIN PRIVATE KEY-----\n...` |
| `OCI_REGION` | OCI region identifier | `us-ashburn-1` |

### Optional Security and Integration Secrets

| Secret Name | Description | Required |
|-------------|-------------|----------|
| `SNYK_TOKEN` | Snyk security scanning token | Optional |
| `SLACK_WEBHOOK_URL` | Slack notification webhook | Optional |
| `GITHUB_TOKEN` | Enhanced GitHub token for additional API access | Optional |

## Environment Secrets

Environment secrets are only available to workflows running in specific environments. Create these environments in GitHub:

**Navigate to:** Repository → Settings → Environments

### Create Environments

1. **development**
   - Protection rules: None (allows all branches)
   - Reviewers: None

2. **staging**
   - Protection rules: Only `main` and `develop` branches
   - Reviewers: Optional

3. **production**
   - Protection rules: Only `main` branch
   - Reviewers: Required (add team members)
   - Wait timer: 5 minutes (optional)

### Environment-Specific Secrets

Each environment should have these secrets configured:

| Secret Name | Development | Staging | Production |
|-------------|-------------|---------|------------|
| `OCI_COMPARTMENT_OCID` | Dev compartment | Staging compartment | Prod compartment |
| `OCI_REGION` | `us-ashburn-1` | `us-phoenix-1` | `us-ashburn-1` |
| `DATABASE_PASSWORD` | Dev password | Staging password | Prod password |
| `API_ENDPOINTS` | Dev endpoints | Staging endpoints | Prod endpoints |

## OCI Credentials Setup

### Step 1: Create OCI User for Automation

1. Log into OCI Console
2. Navigate to Identity & Security → Users
3. Create a new user (e.g., `github-actions-user`)
4. Add user to appropriate groups with required permissions

### Step 2: Generate API Key Pair

```bash
# Generate private key
openssl genrsa -out oci_api_key.pem 2048

# Generate public key
openssl rsa -pubout -in oci_api_key.pem -out oci_api_key_public.pem

# Get fingerprint
openssl rsa -pubout -outform DER -in oci_api_key.pem | openssl md5 -c
```

### Step 3: Upload Public Key to OCI

1. Navigate to the created user in OCI Console
2. Go to API Keys section
3. Add API Key and paste the public key content
4. Note the fingerprint shown in OCI Console

### Step 4: Configure GitHub Secrets

1. Copy the **entire private key content** including headers:
   ```
   -----BEGIN PRIVATE KEY-----
   [key content]
   -----END PRIVATE KEY-----
   ```

2. Add to GitHub as `OCI_PRIVATE_KEY` secret

### Required OCI Permissions

The automation user needs these IAM policies:

```hcl
# Terraform state management
allow group GithubActionsGroup to manage buckets in compartment [compartment-name]
allow group GithubActionsGroup to manage objects in compartment [compartment-name]

# Infrastructure management
allow group GithubActionsGroup to manage all-resources in compartment [compartment-name]

# Identity and security
allow group GithubActionsGroup to use tag-namespaces in tenancy
allow group GithubActionsGroup to inspect tenancies in tenancy
```

## Service Account Configuration

### GitHub Actions Service Account

Create a dedicated service account for GitHub Actions:

```bash
# Example service account creation script
cat > github-actions-sa.json << EOF
{
  "name": "github-actions-automation",
  "description": "Service account for GitHub Actions CI/CD",
  "permissions": [
    "infrastructure.deploy",
    "security.scan",
    "monitoring.read"
  ]
}
EOF
```

### Kubernetes Service Account (if applicable)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: github-actions-sa
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: github-actions-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: github-actions-sa
  namespace: default
```

## API Tokens

### Snyk Token (for security scanning)

1. Sign up at [snyk.io](https://snyk.io)
2. Navigate to Account Settings → API Token
3. Generate and copy token
4. Add as `SNYK_TOKEN` in GitHub secrets

### Slack Webhook (for notifications)

1. Create Slack app at [api.slack.com](https://api.slack.com)
2. Enable Incoming Webhooks
3. Create webhook for your channel
4. Add webhook URL as `SLACK_WEBHOOK_URL`

### External API Integration Examples

```bash
# Example: Adding monitoring service token
MONITORING_API_TOKEN="your-monitoring-service-token"

# Example: Adding container registry token
CONTAINER_REGISTRY_TOKEN="your-registry-token"

# Example: Adding external database credentials
DATABASE_CONNECTION_STRING="encrypted-connection-string"
```

## Security Best Practices

### 1. Secret Rotation

- Rotate OCI API keys every 90 days
- Set up calendar reminders for key rotation
- Use automated rotation where possible

### 2. Least Privilege Access

- Grant minimal required permissions
- Use environment-specific secrets
- Regularly audit access permissions

### 3. Secret Scanning

Enable GitHub's secret scanning:

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scanning
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Run secret scan
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
```

### 4. Encryption at Rest

- All GitHub secrets are encrypted at rest
- Use additional encryption for highly sensitive data
- Consider using external secret management (HashiCorp Vault, AWS Secrets Manager)

### 5. Access Logging

Monitor secret access:

```yaml
# Add to workflows for logging
- name: Log secret access
  run: |
    echo "Secret accessed by: ${{ github.actor }}"
    echo "Workflow: ${{ github.workflow }}"
    echo "Run ID: ${{ github.run_id }}"
```

## Environment Variables

Some configurations can be set as environment variables instead of secrets:

```yaml
env:
  # Non-sensitive configuration
  TERRAFORM_VERSION: "~1.5"
  OCI_DEFAULT_REGION: "us-ashburn-1"
  ENVIRONMENT_NAME: "production"
  
  # Sensitive configuration (use secrets)
  OCI_USER_OCID: ${{ secrets.OCI_USER_OCID }}
  DATABASE_PASSWORD: ${{ secrets.DATABASE_PASSWORD }}
```

## Troubleshooting

### Common Issues

#### 1. OCI Authentication Failures

**Error:** `unauthorized: authentication failed`

**Solutions:**
- Verify fingerprint matches exactly
- Check private key format (should include headers)
- Ensure user has required permissions
- Verify compartment OCID is correct

#### 2. Terraform Backend Access

**Error:** `Failed to configure the backend`

**Solutions:**
- Check bucket permissions
- Verify compartment access
- Ensure backend configuration is correct

#### 3. Secret Not Found

**Error:** `Secret [SECRET_NAME] not found`

**Solutions:**
- Verify secret name spelling
- Check if secret exists in correct scope (repo vs environment)
- Ensure workflow has access to environment

### Debug Commands

Add these to workflows for debugging:

```yaml
- name: Debug OCI Configuration
  run: |
    echo "Checking OCI configuration..."
    echo "Region: ${{ secrets.OCI_REGION }}"
    echo "User OCID: ${OCI_USER_OCID:0:20}..." # Show only first 20 chars
    echo "Tenancy OCID: ${OCI_TENANCY_OCID:0:20}..."
  env:
    OCI_USER_OCID: ${{ secrets.OCI_USER_OCID }}
    OCI_TENANCY_OCID: ${{ secrets.OCI_TENANCY_OCID }}

- name: Test OCI Connectivity
  run: |
    # Test OCI CLI connectivity
    oci iam compartment list --all 2>/dev/null | jq '.data | length' || echo "OCI connectivity failed"
```

### Secret Validation Script

```bash
#!/bin/bash
# validate-secrets.sh
echo "Validating GitHub secrets configuration..."

required_secrets=(
  "OCI_TENANCY_OCID"
  "OCI_COMPARTMENT_OCID"
  "OCI_USER_OCID"
  "OCI_FINGERPRINT"
  "OCI_PRIVATE_KEY"
  "OCI_REGION"
)

for secret in "${required_secrets[@]}"; do
  if [[ -z "${!secret}" ]]; then
    echo "❌ Missing required secret: $secret"
    exit 1
  else
    echo "✅ Found secret: $secret"
  fi
done

echo "✅ All required secrets configured"
```

## Additional Resources

- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [OCI API Key Authentication](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm)
- [Terraform OCI Provider Configuration](https://registry.terraform.io/providers/hashicorp/oci/latest/docs)
- [Security Best Practices for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

## Support

For issues with secret configuration:

1. Check this troubleshooting guide
2. Review GitHub Actions logs
3. Verify OCI Console permissions
4. Contact the DevOps team

---

**Last Updated:** $(date)
**Version:** 1.0
**Maintainer:** DevOps Team

