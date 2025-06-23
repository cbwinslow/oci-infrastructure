# OCI Infrastructure Deployment Guide

This guide provides step-by-step instructions for deploying the OCI infrastructure using Terraform.

## Quick Start

For users who want to get up and running quickly:

```bash
# 1. Clone and setup
git clone <repository-url>
cd terraform-oci

# 2. Configure environment
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 4. Configure instance
./scripts/setup_instance.sh $(terraform output -raw instance_public_ip)
```

## Detailed Deployment Steps

### Pre-Deployment Checklist

Before starting the deployment, ensure you have:

- [ ] **OCI Account**: Active Oracle Cloud account with appropriate permissions
- [ ] **OCI CLI**: Installed and configured with valid credentials
- [ ] **Terraform**: Version >= 1.0.0 installed
- [ ] **SSH Keys**: Generated SSH key pair for instance access
- [ ] **Compartment**: Proper compartment with sufficient quotas
- [ ] **Network Access**: Internet connectivity from deployment machine
- [ ] **Permissions**: IAM permissions for creating resources

### Step 1: Environment Setup

#### 1.1 Verify Prerequisites

```bash
# Check Terraform version
terraform --version
# Expected: Terraform v1.0.0 or later

# Verify OCI CLI configuration
oci iam user get --user-id $(oci iam user list --query 'data[0].id' --raw-output)
# Should return user details without errors

# Test SSH key
ssh-keygen -l -f ~/.ssh/id_rsa.pub
# Should display key fingerprint
```

#### 1.2 Obtain Required Information

Gather the following information before proceeding:

1. **Tenancy OCID**: Found in OCI Console → Administration → Tenancy Details
2. **User OCID**: Found in OCI Console → Identity → Users → Your User
3. **Compartment OCID**: Target compartment for resources
4. **API Key Fingerprint**: From your OCI API key configuration
5. **Private Key Path**: Location of your OCI API private key
6. **SSH Public Key**: Your SSH public key content
7. **Region**: Target OCI region (e.g., us-ashburn-1)
8. **Instance Image OCID**: Ubuntu 20.04 LTS image OCID for your region

#### 1.3 Get Ubuntu Image OCID

```bash
# List available Ubuntu images in your region
oci compute image list \
  --compartment-id <your-tenancy-ocid> \
  --operating-system "Canonical Ubuntu" \
  --shape "VM.Standard.E2.1.Micro" \
  --query 'data[?contains("display-name", `Ubuntu-20.04`)] | [0].id' \
  --raw-output
```

### Step 2: Configuration

#### 2.1 Create Configuration File

```bash
# Copy template
cp terraform.tfvars.example terraform.tfvars

# Secure the file
chmod 600 terraform.tfvars
```

#### 2.2 Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
# OCI Authentication
region           = "us-ashburn-1"                    # Your target region
compartment_id   = "ocid1.compartment.oc1..aaaaaaa" # Your compartment OCID
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaa"     # Your tenancy OCID  
user_ocid        = "ocid1.user.oc1..aaaaaaa"        # Your user OCID
fingerprint      = "aa:bb:cc:dd:ee:ff:11:22:33:44"  # Your API key fingerprint
private_key_path = "~/.oci/oci_api_key.pem"         # Path to private key

# Instance Configuration
ssh_public_key    = "ssh-rsa AAAAB3NzaC1yc2E..."    # Your SSH public key
instance_image_id = "ocid1.image.oc1.iad.aaaaaaa"   # Ubuntu 20.04 LTS OCID
instance_shape    = "VM.Standard.E2.1.Micro"        # Free tier shape

# Database Configuration
db_name           = "ORCL"                           # Database name (1-12 chars)
db_admin_password = "SecurePass123#"                 # Admin password (12+ chars)
db_user_name      = "app_user"                       # Application user name
db_user_password  = "AppPass456#"                    # Application user password
wallet_password   = "WalletPass789#"                 # Wallet password (8+ chars)
db_version        = "19c"                            # Database version (19c/21c)
db_workload       = "OLTP"                           # Workload type

# Network Configuration (optional overrides)
vcn_cidr             = "10.0.0.0/16"                 # VCN CIDR block
subnet_cidr          = "10.0.1.0/24"                # Database subnet
instance_subnet_cidr = "10.0.2.0/24"                # Instance subnet
allowed_ssh_cidr     = "0.0.0.0/0"                  # SSH access (restrict for security!)

# Storage Configuration (optional overrides)
volume_size_in_gbs   = 50                           # Block volume size
backup_retention_days = 30                          # Database backup retention
```

#### 2.3 Validate Configuration

```bash
# Check for syntax errors
terraform validate

# Format configuration files
terraform fmt

# Review the planned changes
terraform plan
```

### Step 3: Infrastructure Deployment

#### 3.1 Initialize Terraform

```bash
# Initialize working directory
terraform init

# Expected output should show successful provider installation
```

#### 3.2 Plan Deployment

```bash
# Create execution plan
terraform plan -out=tfplan

# Review the plan output carefully:
# - Verify resource counts match expectations
# - Check that no unexpected resources will be created/destroyed
# - Ensure sensitive values are not displayed
```

#### 3.3 Apply Configuration

```bash
# Apply the planned changes
terraform apply tfplan

# Monitor progress and wait for completion
# This typically takes 5-15 minutes depending on region and resources
```

#### 3.4 Verify Deployment

```bash
# Check that key outputs are available
terraform output instance_public_ip
terraform output autonomous_database_id

# Save outputs for reference
terraform output > deployment_outputs.txt
```

### Step 4: Post-Deployment Configuration

#### 4.1 Test Basic Connectivity

```bash
# Get instance IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Test SSH connectivity (may take a few minutes for instance to be ready)
ssh -o ConnectTimeout=30 ubuntu@$INSTANCE_IP 'echo "SSH connection successful"'
```

#### 4.2 Run Setup Script

```bash
# Execute the instance setup script
./scripts/setup_instance.sh $INSTANCE_IP

# This script will:
# - Copy wallet files to the instance
# - Extract and configure the wallet
# - Install Oracle client software
# - Set up Python and Node.js environments
# - Configure environment variables
```

#### 4.3 Verify Database Connectivity

```bash
# Test database connection from instance
ssh ubuntu@$INSTANCE_IP << 'EOF'
source ~/.bashrc
export TNS_ADMIN=$HOME/.oracle/wallet/ORCL

# Test with SQL*Plus
echo "Testing SQL*Plus connection..."
sqlplus -S app_user@ORCL_high << 'SQL'
SELECT 'Database connection successful' as status FROM DUAL;
EXIT;
SQL

# Test with Python
echo "Testing Python connection..."
python3 -c "
import cx_Oracle
import os
try:
    conn = cx_Oracle.connect(
        user='app_user',
        password='AppPass456#',
        dsn='ORCL_high',
        config_dir='/home/ubuntu/.oracle/wallet/ORCL'
    )
    cursor = conn.cursor()
    cursor.execute('SELECT SYSDATE FROM DUAL')
    print(f'Python connection successful: {cursor.fetchone()[0]}')
    conn.close()
except Exception as e:
    print(f'Python connection failed: {e}')
"
EOF
```

### Step 5: Application Environment Setup

#### 5.1 Development Environment

```bash
ssh ubuntu@$INSTANCE_IP << 'EOF'
# Create Python virtual environment
python3 -m venv ~/venv/oracle-app
source ~/venv/oracle-app/bin/activate
pip install --upgrade pip
pip install cx_Oracle python-dotenv flask fastapi sqlalchemy

# Set up Node.js project
mkdir -p ~/projects/nodejs
cd ~/projects/nodejs
npm init -y
npm install oracledb dotenv express typescript ts-node @types/node @types/express

echo "Development environment setup complete"
EOF
```

#### 5.2 Environment Variables

```bash
ssh ubuntu@$INSTANCE_IP << 'EOF'
# Create .env file for applications
cat > ~/.env << 'EOL'
DB_USER=app_user
DB_PASSWORD=AppPass456#
TNS_ADMIN=/home/ubuntu/.oracle/wallet/ORCL
DB_SERVICE=ORCL_high
ORACLE_HOME=/usr/lib/oracle/client64
LD_LIBRARY_PATH=/usr/lib/oracle/client64/lib
EOL

chmod 600 ~/.env
echo "Environment variables configured"
EOF
```

### Step 6: Monitoring and Logging Setup

#### 6.1 System Monitoring

```bash
ssh ubuntu@$INSTANCE_IP << 'EOF'
# Install monitoring tools
sudo apt-get update
sudo apt-get install -y htop iotop nethogs

# Create monitoring directories
mkdir -p ~/logs ~/scripts

# Create system monitoring script
cat > ~/scripts/system_monitor.sh << 'EOL'
#!/bin/bash
LOG_FILE="$HOME/logs/system_monitor.log"
echo "=== System Monitor - $(date) ===" >> $LOG_FILE
echo "Uptime: $(uptime)" >> $LOG_FILE
echo "Memory:" >> $LOG_FILE
free -h >> $LOG_FILE
echo "Disk Usage:" >> $LOG_FILE
df -h >> $LOG_FILE
echo "Top Processes:" >> $LOG_FILE
ps aux --sort=-%cpu | head -5 >> $LOG_FILE
echo "" >> $LOG_FILE
EOL

chmod +x ~/scripts/system_monitor.sh

# Schedule monitoring
(crontab -l 2>/dev/null; echo "*/10 * * * * ~/scripts/system_monitor.sh") | crontab -
echo "System monitoring configured"
EOF
```

#### 6.2 Database Health Monitoring

```bash
ssh ubuntu@$INSTANCE_IP << 'EOF'
# Create database health check script
cat > ~/scripts/db_health.sh << 'EOL'
#!/bin/bash
source ~/.env
LOG_FILE="$HOME/logs/db_health.log"

echo "=== Database Health Check - $(date) ===" >> $LOG_FILE

python3 -c "
import cx_Oracle
import os
try:
    conn = cx_Oracle.connect(
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASSWORD'],
        dsn=os.environ['DB_SERVICE'],
        config_dir=os.environ['TNS_ADMIN']
    )
    cursor = conn.cursor()
    cursor.execute('SELECT SYSDATE FROM DUAL')
    result = cursor.fetchone()
    print(f'SUCCESS: Database accessible at {result[0]}')
    conn.close()
except Exception as e:
    print(f'ERROR: Database connection failed - {e}')
" >> $LOG_FILE 2>&1

echo "" >> $LOG_FILE
EOL

chmod +x ~/scripts/db_health.sh

# Schedule database health checks every 15 minutes
(crontab -l 2>/dev/null; echo "*/15 * * * * ~/scripts/db_health.sh") | crontab -
echo "Database health monitoring configured"
EOF
```

### Step 7: Security Hardening

#### 7.1 SSH Security

```bash
ssh ubuntu@$INSTANCE_IP << 'EOF'
# Disable password authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "SSH password authentication disabled"
EOF
```

#### 7.2 Firewall Configuration

```bash
ssh ubuntu@$INSTANCE_IP << 'EOF'
# Configure UFW
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# Show firewall status
sudo ufw status
EOF
```

### Step 8: Backup Configuration

```bash
ssh ubuntu@$INSTANCE_IP << 'EOF'
# Create backup script
cat > ~/scripts/backup.sh << 'EOL'
#!/bin/bash
BACKUP_DIR="$HOME/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup application data
tar -czf $BACKUP_DIR/app_data_$DATE.tar.gz ~/projects ~/configs 2>/dev/null

# Backup logs (last 7 days)
find ~/logs -name "*.log" -mtime -7 | tar -czf $BACKUP_DIR/logs_$DATE.tar.gz -T - 2>/dev/null

# Clean old backups (keep 30 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
EOL

chmod +x ~/scripts/backup.sh

# Schedule daily backups at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * ~/scripts/backup.sh >> ~/logs/backup.log 2>&1") | crontab -
echo "Backup system configured"
EOF
```

## Deployment Verification

### Infrastructure Checklist

- [ ] **Terraform Apply**: Completed without errors
- [ ] **Resources Created**: All expected resources visible in OCI Console
- [ ] **Instance Status**: Instance shows as "Running"
- [ ] **Database Status**: Autonomous Database shows as "Available"
- [ ] **Network Connectivity**: Instance accessible via SSH
- [ ] **Public IP**: Instance has assigned public IP address

### Application Environment Checklist

- [ ] **Oracle Client**: Instant Client installed and configured
- [ ] **Wallet Configuration**: Database wallet extracted and accessible
- [ ] **Python Environment**: cx_Oracle working correctly
- [ ] **Node.js Environment**: oracledb package working correctly
- [ ] **Database Connectivity**: Can connect to database from instance
- [ ] **Environment Variables**: All required variables set correctly

### Security Checklist

- [ ] **SSH Authentication**: Key-based authentication working
- [ ] **Network Security**: Security lists and NSGs configured
- [ ] **Firewall**: UFW enabled and configured
- [ ] **File Permissions**: Wallet files have secure permissions (600)
- [ ] **Password Policies**: All passwords meet complexity requirements

### Monitoring Checklist

- [ ] **System Monitoring**: Scripts installed and scheduled
- [ ] **Database Monitoring**: Health checks configured
- [ ] **Log Rotation**: Logrotate configured for application logs
- [ ] **Backup System**: Automated backups scheduled
- [ ] **Cron Jobs**: All scheduled tasks working correctly

## Troubleshooting Common Issues

### Deployment Issues

#### Terraform Errors

**Error**: "Authentication failed"
```bash
# Solution: Verify OCI CLI configuration
oci iam user get --user-id <your-user-ocid>
```

**Error**: "Quota exceeded"
```bash
# Solution: Check service limits
oci limits resource-availability get --compartment-id <compartment-id> --service-name compute
```

**Error**: "Invalid image OCID"
```bash
# Solution: Get correct image OCID for your region
oci compute image list --compartment-id <tenancy-ocid> --operating-system "Canonical Ubuntu"
```

#### Instance Issues

**Error**: SSH connection timeout
```bash
# Solution 1: Wait for instance to fully boot (can take 5-10 minutes)
# Solution 2: Check security list rules allow SSH (port 22)
# Solution 3: Verify SSH key is correct
```

**Error**: Database wallet not found
```bash
# Solution: Re-run setup script
./scripts/setup_instance.sh $(terraform output -raw instance_public_ip)
```

### Post-Deployment Issues

#### Database Connection Issues

**Error**: "TNS: could not resolve service name"
```bash
# Check TNS_ADMIN environment variable
echo $TNS_ADMIN

# Verify wallet files exist
ls -la ~/.oracle/wallet/ORCL/
```

**Error**: "ORA-28759: failure to open file"
```bash
# Check wallet file permissions
chmod 600 ~/.oracle/wallet/ORCL/*

# Verify wallet password
# Re-download wallet if necessary
```

#### Application Issues

**Error**: cx_Oracle import fails
```bash
# Install Oracle Instant Client
sudo apt-get install oracle-instantclient-basic

# Set environment variables
export LD_LIBRARY_PATH=/usr/lib/oracle/client64/lib:$LD_LIBRARY_PATH
```

**Error**: Node.js oracledb connection fails
```bash
# Verify oracledb package installation
npm list oracledb

# Check Oracle client library path
export LD_LIBRARY_PATH=/usr/lib/oracle/client64/lib:$LD_LIBRARY_PATH
```

## Cleanup and Destruction

### Safe Cleanup Process

```bash
# 1. Backup any important data
ssh ubuntu@$(terraform output -raw instance_public_ip) '~/scripts/backup.sh'

# 2. Download any needed files
scp ubuntu@$(terraform output -raw instance_public_ip):~/important_file.txt ./

# 3. Destroy infrastructure
terraform destroy

# 4. Clean up local files
rm -f terraform.tfstate*
rm -f tfplan
rm -f deployment_outputs.txt
```

### Selective Resource Removal

```bash
# Remove specific resources only
terraform destroy -target=oci_core_instance.app_instance
terraform destroy -target=oci_core_volume.app_volume
```

## Best Practices

### Security
- Always restrict SSH access to specific IP ranges in production
- Use strong passwords that meet Oracle's complexity requirements
- Regularly rotate passwords and API keys
- Monitor access logs for suspicious activity
- Keep wallet files secure and backed up

### Performance
- Monitor resource utilization regularly
- Use connection pooling for database applications
- Implement proper error handling and retry logic
- Cache frequently accessed data
- Optimize database queries

### Maintenance
- Keep system packages updated
- Monitor disk space usage
- Review and rotate logs regularly
- Test backup and recovery procedures
- Document any customizations made

### Cost Optimization
- Use Free Tier resources where possible
- Monitor usage to avoid unexpected charges
- Clean up unused resources regularly
- Use appropriate instance shapes for workload
- Implement auto-shutdown for development environments

---

This guide provides comprehensive deployment procedures. For additional support, refer to the main README.md file and the troubleshooting section.

