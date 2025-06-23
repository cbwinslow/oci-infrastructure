# CI/CD Pipeline Setup Guide

This comprehensive guide walks you through setting up and configuring the complete CI/CD pipeline for the OCI Infrastructure project.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Pipeline Architecture](#pipeline-architecture)
- [Setup Steps](#setup-steps)
- [Configuration](#configuration)
- [Testing the Pipeline](#testing-the-pipeline)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)

## Overview

Our CI/CD pipeline provides:

- **Automated Terraform validation** across multiple environments
- **Comprehensive security scanning** with multiple tools
- **Infrastructure testing** with automated test suites
- **Documentation validation** to ensure compliance
- **Environment-specific deployments** with approval workflows
- **Artifact management** and state preservation

### Pipeline Features

- ✅ Multi-environment support (development, staging, production)
- ✅ Security scanning (Trivy, Checkov, TFSec, Snyk)
- ✅ Code quality checks (TFLint, YAML validation, shell linting)
- ✅ Automated testing with integration tests
- ✅ Documentation validation and generation
- ✅ Artifact preservation and deployment tracking
- ✅ Notification system with workflow summaries

## Prerequisites

### Required Tools

1. **GitHub Account** with admin access to the repository
2. **OCI Account** with appropriate permissions
3. **Local Development Environment:**
   - Git
   - Terraform (>= 1.5)
   - OCI CLI (optional, for testing)

### OCI Permissions

Your OCI user needs the following IAM policies:

```hcl
# Infrastructure Management
allow group GithubActionsGroup to manage all-resources in compartment [compartment-name]

# State Management
allow group GithubActionsGroup to manage buckets in compartment [compartment-name]
allow group GithubActionsGroup to manage objects in compartment [compartment-name]

# Identity and Security
allow group GithubActionsGroup to use tag-namespaces in tenancy
allow group GithubActionsGroup to inspect tenancies in tenancy
allow group GithubActionsGroup to inspect compartments in tenancy
```

## Pipeline Architecture

### Workflow Structure

```mermaid
graph LR
    A[Code Push] --> B[Pre-validation]
    B --> C[Terraform Validation]
    B --> D[Security Scanning]
    B --> E[Code Quality]
    B --> F[Documentation]
    C --> G[Infrastructure Tests]
    D --> G
    E --> G
    F --> G
    G --> H[Deploy Job]
    H --> I[Notification]
```

### Job Dependencies

1. **Pre-validation** - File change detection and structure validation
2. **Terraform Validation** - Format, validate, and plan (parallel across environments)
3. **Security Scanning** - Multiple security tools (parallel)
4. **Code Quality** - Linting and style checks (parallel)
5. **Documentation** - Markdown validation and completeness (parallel)
6. **Infrastructure Tests** - Test suite execution
7. **Deploy** - Environment-specific deployment (conditional)
8. **Notification** - Summary and status reporting

## Setup Steps

### Step 1: Repository Configuration

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd oci-infrastructure
   ```

2. **Validate the setup:**
   ```bash
   chmod +x scripts/validate-deployment.sh
   ./scripts/validate-deployment.sh
   ```

3. **Review the validation report** and address any issues.

### Step 2: GitHub Repository Settings

#### Enable Required Features

1. Navigate to **Settings → General**
   - Enable "Allow merge commits"
   - Enable "Allow squash merging"
   - Disable "Allow rebase merging" (optional)

2. Navigate to **Settings → Branches**
   - Add branch protection rules for `main`:
     - Require pull request reviews
     - Require status checks to pass
     - Require branches to be up to date
     - Include administrators

3. Navigate to **Settings → Actions → General**
   - Set Actions permissions to "Allow all actions and reusable workflows"
   - Enable "Allow GitHub Actions to create and approve pull requests"

### Step 3: Environment Configuration

#### Create GitHub Environments

1. Go to **Settings → Environments**

2. **Create Development Environment:**
   - Name: `development`
   - Protection rules: None
   - Reviewers: None
   - Variables: None initially

3. **Create Staging Environment:**
   - Name: `staging` 
   - Protection rules: 
     - Required reviewers: Add team members
     - Deployment branches: `main` and `develop`
   - Wait timer: 0 minutes

4. **Create Production Environment:**
   - Name: `production`
   - Protection rules:
     - Required reviewers: Add senior team members (minimum 2)
     - Deployment branches: `main` only
   - Wait timer: 5 minutes

### Step 4: Secrets Configuration

Follow the detailed guide in [docs/GITHUB_SECRETS_SETUP.md](./GITHUB_SECRETS_SETUP.md)

#### Repository Secrets (Required)

Navigate to **Settings → Secrets and variables → Actions → Repository secrets**

Add these secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `OCI_TENANCY_OCID` | OCI Tenancy identifier | `ocid1.tenancy.oc1..aaaaa...` |
| `OCI_USER_OCID` | OCI User for automation | `ocid1.user.oc1..aaaaa...` |
| `OCI_FINGERPRINT` | API key fingerprint | `aa:bb:cc:dd:ee:ff:gg:hh:ii:jj:kk:ll:mm:nn:oo:pp` |
| `OCI_PRIVATE_KEY` | Private key (PEM format) | `-----BEGIN PRIVATE KEY-----\n...` |
| `OCI_REGION` | Default OCI region | `us-ashburn-1` |

#### Environment-Specific Secrets

For each environment, add:

| Secret Name | Development | Staging | Production |
|-------------|-------------|---------|------------|
| `OCI_COMPARTMENT_OCID` | Dev compartment OCID | Staging compartment OCID | Prod compartment OCID |

#### Optional Integration Secrets

| Secret Name | Description | Required |
|-------------|-------------|----------|
| `SNYK_TOKEN` | Snyk security scanning | Optional |
| `SLACK_WEBHOOK_URL` | Slack notifications | Optional |

### Step 5: Terraform Backend Configuration

#### Option 1: OCI Object Storage (Recommended)

1. **Create Object Storage Bucket:**
   ```bash
   oci os bucket create \
     --compartment-id $OCI_COMPARTMENT_OCID \
     --name terraform-state-bucket-${ENVIRONMENT} \
     --versioning Enabled
   ```

2. **Configure backend in Terraform:**
   ```hcl
   terraform {
     backend "s3" {
       bucket                      = "terraform-state-bucket"
       key                        = "infrastructure/terraform.tfstate"
       region                     = "us-ashburn-1"
       endpoint                   = "https://namespace.compat.objectstorage.us-ashburn-1.oraclecloud.com"
       skip_region_validation     = true
       skip_credentials_validation = true
       skip_metadata_api_check    = true
       force_path_style           = true
     }
   }
   ```

#### Option 2: Local State (Development Only)

For development and testing, you can use local state with the `-backend=false` flag.

### Step 6: Test Configuration

#### Run Local Validation

```bash
# Validate Terraform configuration
cd terraform-oci
terraform init -backend=false
terraform validate
terraform fmt -check

# Run security scanning locally (optional)
checkov -d . --config-file ../.checkov.yml
```

#### Test Secrets Configuration

```bash
# Create a test script to verify secrets
cat > test-secrets.sh << 'EOF'
#!/bin/bash
echo "Testing OCI connectivity..."
echo "Tenancy: ${OCI_TENANCY_OCID:0:20}..."
echo "User: ${OCI_USER_OCID:0:20}..."
echo "Region: $OCI_REGION"
EOF

chmod +x test-secrets.sh
```

## Configuration

### Workflow Customization

#### Modify Trigger Conditions

Edit `.github/workflows/ci.yml`:

```yaml
on:
  push:
    branches: [ main, develop, feature/* ]  # Add more branches
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * 1'  # Weekly security scan
```

#### Customize Security Scanning

Edit `.checkov.yml` to skip specific checks:

```yaml
skip-check:
  - CKV_OCI_13  # Allow unrestricted ingress for development
  
# Add custom severity levels
severity:
  CRITICAL:
    - CKV_SECRET_1
    - CKV_SECRET_5
```

#### Configure TFLint Rules

Edit `.tflint.hcl`:

```hcl
rule "terraform_naming_convention" {
  enabled = true
  
  variable {
    format = "snake_case"
  }
}
```

### Environment-Specific Configuration

#### Development Environment

- Uses `terraform-oci/free-tier` directory
- No deployment restrictions
- Relaxed security checks
- Full logging enabled

#### Staging Environment

- Uses `terraform-oci` directory
- Requires code review
- Full security scanning
- Performance testing enabled

#### Production Environment

- Uses `terraform-oci` directory  
- Requires 2+ reviewers
- Strict security compliance
- Deployment approval required
- 5-minute wait timer

## Testing the Pipeline

### Manual Testing

#### 1. Test Workflow Triggers

```bash
# Create a test branch
git checkout -b test/ci-pipeline

# Make a small change
echo "# Test Change" >> docs/test.md

# Commit and push
git add docs/test.md
git commit -m "test: trigger CI pipeline"
git push origin test/ci-pipeline
```

#### 2. Create Pull Request

1. Create PR from test branch to main
2. Verify all checks run successfully
3. Review workflow logs in Actions tab

#### 3. Test Manual Deployment

1. Go to **Actions → Deploy to Environment**
2. Click "Run workflow"
3. Select environment: `development`
4. Select action: `plan`
5. Run workflow and review results

### Automated Testing

The pipeline includes several automated tests:

#### Pre-validation Tests
- Repository structure validation
- Required file presence
- Basic syntax checking

#### Terraform Tests
- Format validation (`terraform fmt`)
- Configuration validation (`terraform validate`)
- Plan generation and review

#### Security Tests
- Static analysis with Checkov
- Vulnerability scanning with Trivy
- Infrastructure security with TFSec
- Optional: Snyk scanning

#### Quality Tests  
- TFLint for Terraform best practices
- YAML syntax validation
- Shell script linting with ShellCheck
- Markdown linting

#### Integration Tests
- Infrastructure deployment tests
- Connectivity validation
- Resource verification

## Monitoring and Maintenance

### Workflow Monitoring

#### GitHub Actions Insights

1. **Navigate to Actions tab**
2. **Review workflow runs:**
   - Success/failure rates
   - Execution times
   - Resource usage

3. **Set up notifications:**
   - Email notifications for failures
   - Slack integration (if configured)

#### Key Metrics to Monitor

- **Success Rate:** Target >95% for main branch
- **Execution Time:** Baseline and monitor for regressions  
- **Security Issues:** Track and trend security findings
- **Test Coverage:** Monitor test execution and results

### Maintenance Tasks

#### Weekly
- Review failed workflows and address issues
- Update dependency versions if needed
- Review security scan results

#### Monthly
- Rotate OCI API keys
- Review and update security policies
- Update documentation as needed
- Review and clean up old artifacts

#### Quarterly
- Update Terraform provider versions
- Review and update IAM permissions
- Security audit of the pipeline
- Performance optimization review

### Logging and Artifacts

#### Workflow Artifacts
- Terraform plans (30-day retention)
- Security scan results (30-day retention)
- Test results (30-day retention)
- Deployment artifacts (90-day retention)

#### Log Analysis

```bash
# Download workflow logs using GitHub CLI
gh run list --workflow="CI/CD Pipeline"
gh run download <run-id>
```

## Troubleshooting

### Common Issues

#### 1. OCI Authentication Failures

**Symptoms:**
- `Error: authentication failed`
- `401 Unauthorized` errors

**Solutions:**
```bash
# Verify fingerprint matches
openssl rsa -pubout -outform DER -in private_key.pem | openssl md5 -c

# Check private key format
head -n1 private_key.pem  # Should show -----BEGIN PRIVATE KEY-----

# Verify user permissions in OCI Console
```

#### 2. Terraform State Conflicts

**Symptoms:**
- `Error: state lock`
- `Backend configuration changed`

**Solutions:**
```bash
# Force unlock (use carefully)
terraform force-unlock <lock-id>

# Reconfigure backend
terraform init -reconfigure
```

#### 3. Security Scan Failures

**Symptoms:**
- High number of security findings
- Pipeline failing on security checks

**Solutions:**
```yaml
# Temporarily use soft-fail mode in .checkov.yml
soft-fail: true

# Skip specific checks during development
skip-check:
  - CKV_OCI_13
```

#### 4. Resource Quota Exceeded

**Symptoms:**
- `Error: 400-LimitExceeded`
- Infrastructure creation failures

**Solutions:**
- Review OCI service limits
- Use free-tier configuration for development
- Clean up unused resources

### Debug Mode

Enable debug logging in workflows:

```yaml
- name: Debug Information
  run: |
    echo "Debug mode enabled"
    env | grep -E '^(GITHUB_|TF_|OCI_)' | sort
    terraform version
    oci --version
  env:
    ACTIONS_STEP_DEBUG: true
```

### Getting Help

#### Internal Support
1. Check this documentation
2. Review workflow logs in GitHub Actions
3. Check the validation report: `./scripts/validate-deployment.sh`

#### External Resources
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform OCI Provider](https://registry.terraform.io/providers/hashicorp/oci/latest/docs)
- [OCI Documentation](https://docs.oracle.com/en-us/iaas/)

#### Emergency Procedures

**Pipeline Down:**
1. Check GitHub status: [githubstatus.com](https://githubstatus.com)
2. Verify OCI service health
3. Fall back to manual deployment if needed

**Security Incident:**
1. Disable affected workflows immediately
2. Rotate all credentials
3. Review audit logs
4. Follow incident response procedures

## Best Practices

### Security
- Never commit secrets to the repository
- Rotate credentials regularly (every 90 days)
- Use least-privilege access principles
- Enable branch protection rules

### Development
- Always create feature branches
- Require pull request reviews
- Run local validation before pushing
- Keep documentation updated

### Operations  
- Monitor pipeline health regularly
- Set up alerting for failures
- Maintain artifact retention policies
- Regular backup of critical configurations

### Performance
- Cache dependencies where possible
- Parallelize independent jobs
- Optimize artifact sizes
- Monitor execution times

---

**Document Version:** 1.0  
**Last Updated:** $(date)  
**Maintainer:** DevOps Team

For questions or issues, please create a GitHub issue or contact the DevOps team.

