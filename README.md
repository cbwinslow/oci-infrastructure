# OCI Infrastructure Project

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple?logo=terraform)](https://terraform.io)
[![OCI](https://img.shields.io/badge/Oracle_Cloud-Infrastructure-red?logo=oracle)](https://cloud.oracle.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Security](https://img.shields.io/badge/Security-Enhanced-blue)](SECURITY.md)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen)](tests/)

This repository contains a comprehensive Infrastructure as Code (IaC) solution for managing Oracle Cloud Infrastructure (OCI) resources using Terraform. The project includes automated deployment, security enhancements, monitoring, and maintenance capabilities.

## 🏗️ Project Overview

This project provides:
- **Complete OCI infrastructure automation** using Terraform
- **AI-powered repository management** for automated maintenance
- **Comprehensive security framework** with automated compliance
- **Monitoring and alerting** for infrastructure health
- **Automated testing and validation** for all components
- **Complete documentation** with deployment guides

## 📁 Directory Structure

```
oci-infrastructure/
├── terraform-oci/           # Main Terraform configurations
│   └── terraform-oci/      # Core infrastructure code
│       ├── main.tf          # Primary infrastructure definitions
│       ├── variables.tf     # Input variables
│       ├── outputs.tf       # Output values
│       └── terraform.tfvars.example
├── agents/                  # AI agent system for repo management
│   └── repo_repair/        # Repository maintenance automation
├── scripts/                 # Automation and utility scripts
│   ├── deploy.sh           # Main deployment script
│   ├── setup_instance.sh   # Instance configuration
│   └── validate.sh         # Validation scripts
├── tests/                   # Comprehensive test suite
│   ├── integration/        # Integration tests
│   ├── security/           # Security validation tests
│   └── results/            # Test results and reports
├── docs/                    # Additional documentation
├── logs/                    # Logging and monitoring
└── PROJECT_PLAN.md         # Project plan and milestones
```

## 🚀 Quick Start

### Prerequisites

Before you begin, ensure you have:

- **Terraform** >= 1.0.0 ([Download](https://terraform.io/downloads.html))
- **OCI CLI** configured with valid credentials ([Setup Guide](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm))
- **Git** for version control
- **SSH key pair** for instance access
- **Oracle Cloud account** with appropriate permissions

### System Requirements

- **Operating System**: Linux, macOS, or Windows WSL2
- **Memory**: Minimum 4GB RAM
- **Storage**: At least 2GB free space
- **Network**: Internet connectivity for provider downloads

## 📋 Complete Setup Instructions

### Step 1: Repository Setup

```bash
# Clone the repository
git clone https://github.com/your-username/oci-infrastructure.git
cd oci-infrastructure

# Verify repository structure
ls -la

# Check current status
git status
```

### Step 2: Environment Preparation

#### 2.1 Install Required Tools

**Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install OCI CLI
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

**macOS:**
```bash
# Install using Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install oci-cli
```

**Windows (WSL2):**
```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install OCI CLI
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

#### 2.2 Verify Installations

```bash
# Check Terraform version
terraform --version
# Expected: Terraform v1.0.0 or later

# Check OCI CLI
oci --version
# Expected: oci-cli version information

# Verify Git configuration
git config --global user.name
git config --global user.email
```

### Step 3: OCI Configuration

#### 3.1 Configure OCI CLI

```bash
# Run OCI configuration
oci setup config

# Follow prompts to enter:
# - User OCID
# - Tenancy OCID  
# - Region
# - Generate new API key (recommended)
```

#### 3.2 Gather Required Information

Collect the following before proceeding:

1. **Tenancy OCID**: OCI Console → Administration → Tenancy Details
2. **User OCID**: OCI Console → Identity → Users → Your User
3. **Compartment OCID**: Target compartment for resources
4. **Region**: Your target OCI region (e.g., us-ashburn-1)
5. **API Key Fingerprint**: From your OCI API key setup
6. **SSH Public Key**: Your SSH public key content

#### 3.3 Generate SSH Keys (if needed)

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Display public key
cat ~/.ssh/id_rsa.pub
```

### Step 4: Project Configuration

#### 4.1 Navigate to Terraform Directory

```bash
cd terraform-oci/terraform-oci
```

#### 4.2 Create Configuration File

```bash
# Copy template
cp terraform.tfvars.example terraform.tfvars

# Secure the file
chmod 600 terraform.tfvars
```

#### 4.3 Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
# OCI Authentication (REQUIRED)
region           = "us-ashburn-1"                    # Your target region
compartment_id   = "ocid1.compartment.oc1..aaaaaaa" # Your compartment OCID
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaa"     # Your tenancy OCID  
user_ocid        = "ocid1.user.oc1..aaaaaaa"        # Your user OCID
fingerprint      = "aa:bb:cc:dd:ee:ff:11:22:33:44"  # Your API key fingerprint
private_key_path = "~/.oci/oci_api_key.pem"         # Path to private key

# Instance Configuration (REQUIRED)
ssh_public_key    = "ssh-rsa AAAAB3NzaC1yc2E..."    # Your SSH public key
instance_image_id = "ocid1.image.oc1.iad.aaaaaaa"   # Ubuntu 20.04 LTS OCID
instance_shape    = "VM.Standard.E2.1.Micro"        # Free tier compatible

# Database Configuration (REQUIRED)
db_name           = "ORCL"                           # Database name (1-12 chars)
db_admin_password = "SecurePass123#"                 # Admin password (12+ chars)
db_user_name      = "app_user"                       # Application user name
db_user_password  = "AppPass456#"                    # Application user password
wallet_password   = "WalletPass789#"                 # Wallet password (8+ chars)

# Optional Overrides
vcn_cidr             = "10.0.0.0/16"                 # VCN CIDR block
subnet_cidr          = "10.0.1.0/24"                # Database subnet
instance_subnet_cidr = "10.0.2.0/24"                # Instance subnet
allowed_ssh_cidr     = "0.0.0.0/0"                  # SSH access (restrict for security!)
```

**Security Note**: Always restrict `allowed_ssh_cidr` to your specific IP range in production!

### Step 5: Deployment Validation

#### 5.1 Initialize Terraform

```bash
# Initialize working directory
terraform init

# Expected output: Successful provider installation
```

#### 5.2 Validate Configuration

```bash
# Format configuration files
terraform fmt

# Validate syntax
terraform validate

# Expected output: Success! The configuration is valid.
```

#### 5.3 Plan Deployment

```bash
# Create execution plan
terraform plan -out=tfplan

# Review the plan output carefully:
# - Verify resource counts match expectations  
# - Check no unexpected resources will be created/destroyed
# - Ensure sensitive values are not displayed
```

### Step 6: Infrastructure Deployment

#### 6.1 Deploy Infrastructure

```bash
# Apply the planned changes
terraform apply tfplan

# Confirm with 'yes' when prompted
# Wait for completion (typically 5-15 minutes)
```

#### 6.2 Verify Deployment

```bash
# Check outputs
terraform output

# Save outputs for reference
terraform output > deployment_outputs.txt

# Get instance IP
echo "Instance IP: $(terraform output -raw instance_public_ip)"
```

### Step 7: Post-Deployment Setup

#### 7.1 Run Setup Script

```bash
# Return to project root
cd ../..

# Execute setup script
./scripts/setup_instance.sh $(cd terraform-oci/terraform-oci && terraform output -raw instance_public_ip)

# This script configures:
# - Oracle client software
# - Database wallet
# - Development environments
# - Monitoring tools
```

#### 7.2 Test Connectivity

```bash
# Test SSH connection
INSTANCE_IP=$(cd terraform-oci/terraform-oci && terraform output -raw instance_public_ip)
ssh ubuntu@$INSTANCE_IP 'echo "SSH connection successful"'

# Test database connectivity
ssh ubuntu@$INSTANCE_IP 'source ~/.bashrc && sqlplus -S app_user@ORCL_high <<< "SELECT 'Database connected' FROM DUAL;"'
```

## 🔧 Advanced Configuration

### Automation Scripts

The project includes several automation scripts:

- **`scripts/deploy.sh`**: Complete deployment automation
- **`scripts/validate.sh`**: Comprehensive validation
- **`scripts/monitor.sh`**: Infrastructure monitoring
- **`scripts/backup.sh`**: Automated backup procedures

### AI Agent System

The repository includes an AI agent system for automated maintenance:

```bash
# Initialize AI agents
./agents/repo_repair/scripts/fix_permissions.sh

# Check agent status
cat agents/repo_repair/config/service_config.json
```

### Monitoring and Logging

Monitoring is automatically configured:

- **System metrics**: CPU, memory, disk usage
- **Database health**: Connection tests and performance
- **Security monitoring**: Access logs and security events
- **Application logs**: Custom application logging

## 🧪 Testing

### Run Test Suite

```bash
# Execute all tests
./scripts/run_tests.sh

# Run specific test categories
./tests/integration/test_terraform.sh     # Infrastructure tests
./tests/security/test_security.sh         # Security validation
./tests/performance/test_performance.sh   # Performance benchmarks
```

### Validation Scripts

```bash
# Validate Terraform configurations
./scripts/validate.sh

# Check security compliance
./scripts/security_check.sh

# Performance benchmarking
./scripts/performance_test.sh
```

## 📚 Documentation

- **[Project Plan](PROJECT_PLAN.md)**: Detailed project timeline and milestones
- **[Software Requirements](SRS.md)**: Comprehensive system requirements
- **[Security Policy](SECURITY.md)**: Security guidelines and compliance
- **[Deployment Guide](terraform-oci/terraform-oci/DEPLOYMENT_GUIDE.md)**: Detailed deployment procedures
- **[API Documentation](docs/)**: Complete API reference

## 🔒 Security

This project implements comprehensive security measures:

- **Infrastructure security**: Network segmentation, security groups
- **Access control**: IAM policies, least privilege principle  
- **Data protection**: Encryption at rest and in transit
- **Monitoring**: Security event logging and alerting
- **Compliance**: Automated compliance checking

Refer to [SECURITY.md](SECURITY.md) for detailed security information.

## 🚨 Troubleshooting

### Common Issues

#### Authentication Errors
```bash
# Verify OCI configuration
oci iam user get --user-id $(oci iam user list --query 'data[0].id' --raw-output)
```

#### Terraform Errors
```bash
# Clear Terraform state if corrupted
rm -rf .terraform/
terraform init
```

#### SSH Connection Issues
```bash
# Check instance status
oci compute instance list --compartment-id <compartment-id>

# Verify security list rules
oci network security-list list --compartment-id <compartment-id>
```

#### Database Connection Problems
```bash
# Re-run instance setup
./scripts/setup_instance.sh $INSTANCE_IP

# Check wallet configuration
ssh ubuntu@$INSTANCE_IP 'ls -la ~/.oracle/wallet/ORCL/'
```

### Getting Help

1. **Check logs**: Review logs in `logs/` directory
2. **Run diagnostics**: Use `./scripts/diagnose.sh`
3. **Review documentation**: Check relevant documentation files
4. **Check issues**: Search project issues on GitHub

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines

- Follow Terraform best practices
- Include tests for new features
- Update documentation
- Follow security guidelines
- Use conventional commit messages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:

- **Email**: support@example.com
- **Documentation**: Check the `docs/` directory
- **Issues**: Open a GitHub issue
- **Security**: Report security issues privately

## 🏆 Acknowledgments

- Oracle Cloud Infrastructure team for excellent documentation
- Terraform community for best practices
- Open source security tools and frameworks
- Contributors and testers

---

**Project Status**: ✅ Production Ready | **Last Updated**: 2025-06-23 | **Version**: 1.0.0

## Repository Repair Tool

Automated tool for maintaining repository health:
- Permission management
- Change handling
- Repository synchronization
- Documentation updates

The repository repair tool ensures optimal repository maintenance by:
- Monitoring file permissions and correcting inconsistencies
- Tracking and managing repository changes automatically
- Synchronizing repository state across different environments
- Maintaining up-to-date documentation and metadata

### Usage

The repository repair tool can be invoked manually or scheduled to run automatically:

```bash
# Manual execution
./scripts/repo-repair-tool.sh

# Check repository health status
./scripts/repo-repair-tool.sh --status

# Perform specific repairs
./scripts/repo-repair-tool.sh --fix-permissions
./scripts/repo-repair-tool.sh --sync-docs
```

## Security

Please refer to SECURITY.md for security considerations and compliance requirements.

## Contributing

1. Create a feature branch
2. Make your changes
3. Submit a pull request

## License

[License details to be added]

