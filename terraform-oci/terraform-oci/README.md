# OCI Infrastructure and Database Access Guide

This comprehensive guide explains how to deploy, configure, and access an Oracle Cloud Infrastructure (OCI) environment featuring an Autonomous Database, compute instances, and complete networking infrastructure using Terraform Infrastructure as Code.

## Table of Contents
- [Infrastructure Overview](#infrastructure-overview)
- [Infrastructure Components](#infrastructure-components)
- [Security Configurations](#security-configurations)
- [Monitoring and Logging](#monitoring-and-logging)
- [Prerequisites](#prerequisites)
- [Deployment Instructions](#deployment-instructions)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Database Access](#database-access)
  - [Python Examples](#python-examples)
  - [TypeScript Examples](#typescript-examples)
  - [Other Methods](#other-methods)
- [Manual Post-Deployment Steps](#manual-post-deployment-steps)
- [Security Considerations](#security-considerations)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Infrastructure Overview

This Terraform configuration deploys a complete OCI infrastructure stack featuring:
- **Autonomous Database** (Free Tier) with secure wallet-based authentication
- **Compute Instance** (Free Tier) pre-configured for database connectivity
- **Complete Networking** with VCN, subnets, security lists, and NSGs
- **Block Storage** with automated attachment and configuration
- **Monitoring and Logging** with OCI native services
- **Security** hardened with Network Security Groups and restricted access

## Infrastructure Components

### Core Infrastructure Resources

#### 1. **Networking Infrastructure**
- **Virtual Cloud Network (VCN)**: `10.0.0.0/16` CIDR with DNS resolution
- **Internet Gateway**: Provides public internet access
- **Route Table**: Routes traffic to internet gateway for public access
- **Subnets**:
  - Database Subnet: `10.0.1.0/24` for database access
  - Instance Subnet: `10.0.2.0/24` for compute instances
- **Security Lists**: Traditional stateful firewall rules
- **Network Security Groups (NSGs)**: Application-specific security rules

#### 2. **Database Resources**
- **Autonomous Database (Free Tier)**:
  - 1 OCPU, 1TB storage
  - Oracle 19c or 21c
  - OLTP workload optimized
  - Auto-scaling disabled (Free Tier)
  - Backup retention: 30 days (configurable 7-60 days)
- **Database User**: Application-specific user with CONNECT/RESOURCE roles
- **Wallet Configuration**: Secure connection wallet with SSL encryption
- **Connection Services**: HIGH, MEDIUM, LOW performance tiers

#### 3. **Compute Infrastructure**
- **Instance**: VM.Standard.E2.1.Micro (Free Tier)
- **Operating System**: Ubuntu 20.04 LTS
- **Public IP**: Assigned for external access
- **Block Volume**: 50GB additional storage (configurable)
- **Volume Attachment**: Paravirtualized for optimal performance

#### 4. **Pre-installed Software Stack**
- **Oracle Instant Client**: Latest version with SQL*Plus
- **Development Environments**:
  - Python 3.x with cx_Oracle, python-dotenv
  - Node.js with oracledb, typescript, ts-node
  - Development tools and utilities

#### 5. **Monitoring and Logging**
- **OCI Logging Service**: Centralized log management
- **Instance Monitoring**: CPU, memory, network, disk metrics
- **Database Monitoring**: Built-in autonomous monitoring
- **Management Agent**: Enabled for advanced monitoring

## Security Configurations

### Network Security

#### Security Lists (Traditional Firewall)
**Database Security List**:
- **Inbound Rules**:
  - Port 1521 (SQL*Net): Database connections
  - Port 443 (HTTPS): SQL Developer Web, APEX
- **Outbound Rules**: All traffic allowed

**Instance Security List**:
- **Inbound Rules**:
  - Port 22 (SSH): Remote administration
  - Port 80 (HTTP): Web applications
  - Port 443 (HTTPS): Secure web applications
- **Outbound Rules**: All traffic allowed

#### Network Security Groups (Application-level)
**SSH Security Group**:
- **Purpose**: Secure shell access control
- **Rules**: TCP/22 from configurable CIDR (default: 0.0.0.0/0)
- **Best Practice**: Restrict to specific IP ranges

**Web Security Group**:
- **Purpose**: HTTP/HTTPS web traffic
- **Rules**: 
  - TCP/80 from 0.0.0.0/0
  - TCP/443 from 0.0.0.0/0

**Database Security Group**:
- **Purpose**: Database connectivity from instances
- **Rules**: TCP/1522 from instance subnet only
- **Principle**: Least privilege access

### Authentication and Access Control

#### Database Security
- **Wallet-based Authentication**: mTLS encryption
- **SSL/TLS Encryption**: All connections encrypted
- **User Separation**: Dedicated application user (non-ADMIN)
- **Password Policies**: Enforced complexity requirements

#### Instance Security
- **SSH Key Authentication**: No password authentication
- **Public Key Management**: User-provided SSH keys
- **File Permissions**: Restrictive wallet permissions (600)
- **Environment Isolation**: User-specific configuration

### Security Best Practices Implemented

1. **Principle of Least Privilege**:
   - Database user has minimal required permissions
   - Network access restricted to necessary ports
   - Instance access via SSH keys only

2. **Defense in Depth**:
   - Multiple security layers (Security Lists + NSGs)
   - Application-level and network-level controls
   - Encrypted connections at all levels

3. **Secrets Management**:
   - Sensitive variables marked as sensitive
   - Passwords never logged or displayed
   - Wallet files protected with proper permissions

4. **Network Isolation**:
   - Database access restricted to instance subnet
   - Public access only where necessary
   - Internal traffic isolated from external

## Monitoring and Logging

### OCI Native Monitoring

#### Instance Monitoring
- **Metrics Collection**:
  - CPU utilization
  - Memory usage
  - Network throughput
  - Disk I/O performance
  - Custom application metrics

- **Management Agent**: 
  - Enabled for advanced monitoring
  - Plugin-based architecture
  - Real-time performance data

#### Database Monitoring
- **Autonomous Database Insights**:
  - Automatic performance tuning
  - SQL performance monitoring
  - Resource utilization tracking
  - Automatic anomaly detection

- **Built-in Dashboards**:
  - Real-time performance metrics
  - Historical trend analysis
  - Capacity planning insights

### Logging Infrastructure

#### Centralized Logging
- **Log Group**: `example-log-group` for organized log management
- **Service Logs**: Instance and application logs
- **Retention**: Configurable log retention policies
- **Access**: Role-based access to log data

#### Log Types
1. **System Logs**: OS-level events and errors
2. **Application Logs**: Custom application logging
3. **Database Logs**: Database activity and performance
4. **Security Logs**: Access attempts and security events

### Alerting and Notifications

#### Recommended Alert Configurations
1. **Performance Alerts**:
   - CPU usage > 80% for 5 minutes
   - Memory usage > 90%
   - Database connection failures

2. **Security Alerts**:
   - Failed SSH login attempts
   - Unusual network traffic patterns
   - Database authentication failures

3. **Availability Alerts**:
   - Instance down/unreachable
   - Database unavailable
   - Network connectivity issues

### Monitoring Best Practices

1. **Proactive Monitoring**:
   - Set up alerts before issues occur
   - Monitor trends, not just current state
   - Regular review of monitoring configurations

2. **Log Management**:
   - Centralize all logs for correlation
   - Implement log rotation and retention
   - Use structured logging formats

3. **Performance Optimization**:
   - Regular performance baseline reviews
   - Capacity planning based on trends
   - Optimize based on monitoring insights

## Prerequisites

### Required Software
1. **OCI CLI** configured with valid credentials
2. **Terraform** >= 1.0.0 installed
3. **SSH key pair** for instance access
4. **Oracle Cloud account** with Free Tier access
5. **Git** for version control
6. **Text editor** for configuration files

### OCI Account Requirements
- Valid OCI account with appropriate permissions
- Access to create resources in your tenancy
- Compartment with sufficient quota for:
  - 1 Autonomous Database (Free Tier)
  - 1 Compute Instance (Free Tier)
  - VCN and networking resources
  - Block storage (50GB)

### Network Access
- Internet connectivity for Terraform to communicate with OCI APIs
- SSH client for connecting to instances
- Access to Oracle and Ubuntu package repositories

## Deployment Instructions

### Step 1: Environment Preparation

1. **Clone the repository**:
```bash
git clone <repository-url>
cd terraform-oci
```

2. **Verify prerequisites**:
```bash
# Check Terraform installation
terraform --version

# Verify OCI CLI configuration
oci iam user get --user-id <your-user-ocid>

# Test SSH key
ssh-keygen -l -f ~/.ssh/id_rsa.pub
```

### Step 2: Configuration Setup

1. **Create terraform.tfvars file**:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. **Configure variables** in `terraform.tfvars`:
```hcl
# OCI Authentication
region           = "us-ashburn-1"  # Your preferred region
compartment_id   = "ocid1.compartment.oc1..aaaaaaaaxxxxxxx"
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaaxxxxxxx"
user_ocid        = "ocid1.user.oc1..aaaaaaaaxxxxxxx"
fingerprint      = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
private_key_path = "~/.oci/oci_api_key.pem"

# Instance Configuration
ssh_public_key    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
instance_image_id = "ocid1.image.oc1.iad.aaaaaaaaxxxxxxx"  # Ubuntu 20.04 LTS
instance_shape    = "VM.Standard.E2.1.Micro"  # Free tier

# Database Configuration
db_name           = "ORCL"
db_admin_password = "SecurePassword123#"
db_user_name      = "app_user"
db_user_password  = "AppUserPass456#"
wallet_password   = "WalletPass789#"
db_version        = "19c"
db_workload       = "OLTP"

# Network Configuration
vcn_cidr             = "10.0.0.0/16"
subnet_cidr          = "10.0.1.0/24"
instance_subnet_cidr = "10.0.2.0/24"
allowed_ssh_cidr     = "0.0.0.0/0"  # Restrict this for production!

# Storage Configuration
volume_size_in_gbs   = 50
backup_retention_days = 30
```

3. **Secure the configuration file**:
```bash
chmod 600 terraform.tfvars
```

### Step 3: Infrastructure Deployment

1. **Initialize Terraform**:
```bash
terraform init
```

2. **Validate configuration**:
```bash
terraform validate
```

3. **Plan deployment**:
```bash
terraform plan -out=tfplan
```

4. **Review the plan** carefully, ensuring:
   - All required resources are included
   - No unexpected changes
   - Resource counts match expectations

5. **Apply the configuration**:
```bash
terraform apply tfplan
```

6. **Save important outputs**:
```bash
terraform output > deployment_outputs.txt
```

### Step 4: Verify Deployment

1. **Check resource status** in OCI Console:
   - Navigate to Compute → Instances
   - Verify instance is "Running"
   - Check Database → Autonomous Database
   - Confirm database is "Available"

2. **Test connectivity**:
```bash
# Get instance IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Test SSH connectivity
ssh -o ConnectTimeout=10 ubuntu@$INSTANCE_IP 'echo "SSH working"'
```

### Step 5: Instance Configuration

1. **Run the setup script**:
```bash
./scripts/setup_instance.sh $(terraform output -raw instance_public_ip)
```

2. **Verify setup completion**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) 'ls -la ~/.oracle/wallet/'
```

### Step 6: Database Connection Testing

1. **Test basic connectivity**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
source ~/.bashrc
export TNS_ADMIN=$HOME/.oracle/wallet/ORCL
sqlplus app_user@ORCL_high
EOF
```

2. **Test programmatic access**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
cd ~/app
python3 -c "import cx_Oracle; print('cx_Oracle installed successfully')"
node -e "const oracledb = require('oracledb'); console.log('oracledb installed successfully');"
EOF
```

### Deployment Verification Checklist

- [ ] Terraform apply completed without errors
- [ ] All resources show as "Available" or "Running" in OCI Console
- [ ] Instance accessible via SSH
- [ ] Database wallet extracted and configured
- [ ] Oracle Instant Client installed and working
- [ ] Python and Node.js environments configured
- [ ] Database connectivity tested successfully
- [ ] Monitoring and logging services active

## Post-Deployment Configuration

### Immediate Configuration Tasks

1. **Update system packages**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
sudo apt-get update && sudo apt-get upgrade -y
sudo reboot
EOF
```

2. **Configure database environment**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
# Create .env file for applications
cat > ~/.env << 'EOL'
DB_USER=app_user
DB_PASSWORD=AppUserPass456#
TNS_ADMIN=/home/ubuntu/.oracle/wallet/ORCL
DB_SERVICE=ORCL_high
EOL
chmod 600 ~/.env

# Test environment
source ~/.env
echo "Database user: $DB_USER"
echo "TNS Admin: $TNS_ADMIN"
EOL
```

3. **Set up application directories**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
mkdir -p ~/projects/{python,nodejs,scripts}
mkdir -p ~/logs
mkdir -p ~/backups
EOF
```

### Security Hardening

1. **Configure SSH security**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
# Disable password authentication (if not already done)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
EOF
```

2. **Set up firewall rules**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
# Configure UFW (optional additional layer)
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw status
EOF
```

3. **Configure log rotation**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
sudo tee /etc/logrotate.d/application << 'EOL'
/home/ubuntu/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
}
EOL
EOF
```

### Development Environment Setup

1. **Python development environment**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
# Create Python virtual environment
python3 -m venv ~/venv/oracle-app
source ~/venv/oracle-app/bin/activate
pip install --upgrade pip
pip install cx_Oracle python-dotenv flask fastapi sqlalchemy

# Add to .bashrc
echo "alias activate-oracle='source ~/venv/oracle-app/bin/activate'" >> ~/.bashrc
EOF
```

2. **Node.js development environment**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
# Set up global npm packages
npm install -g typescript ts-node nodemon

# Create sample package.json
cd ~/projects/nodejs
npm init -y
npm install oracledb dotenv express @types/node @types/express
EOF
```

### Monitoring Setup

1. **Configure system monitoring**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
# Install system monitoring tools
sudo apt-get install -y htop iotop nethogs

# Create monitoring script
cat > ~/scripts/system_check.sh << 'EOL'
#!/bin/bash
echo "=== System Status Check ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Disk Usage:"
df -h
echo "Memory Usage:"
free -h
echo "Top Processes:"
ps aux --sort=-%cpu | head -10
EOL

chmod +x ~/scripts/system_check.sh

# Add to crontab for regular checks
(crontab -l 2>/dev/null; echo "0 */6 * * * ~/scripts/system_check.sh >> ~/logs/system_check.log 2>&1") | crontab -
EOF
```

2. **Database connection monitoring**:
```bash
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
cat > ~/scripts/db_health_check.sh << 'EOL'
#!/bin/bash
source ~/.bashrc
source ~/.env

echo "=== Database Health Check ==="
echo "Date: $(date)"

# Test database connectivity
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
    print(f'Database connection successful. Time: {result[0]}')
    conn.close()
except Exception as e:
    print(f'Database connection failed: {e}')
"
EOL

chmod +x ~/scripts/db_health_check.sh

# Add to crontab for regular checks
(crontab -l 2>/dev/null; echo "*/15 * * * * ~/scripts/db_health_check.sh >> ~/logs/db_health.log 2>&1") | crontab -
EOF
```

## Manual Post-Deployment Steps

### Required Manual Configuration

#### 1. **SSL Certificate Setup** (For Production)

```bash
# Install Certbot for Let's Encrypt certificates
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
sudo apt-get install -y certbot

# Note: You'll need a domain name pointing to your instance
# sudo certbot certonly --standalone -d your-domain.com
# sudo certbot renew --dry-run
EOF
```

#### 2. **Database Schema Creation**

```bash
# Create application-specific database objects
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
sqlplus app_user@ORCL_high << 'SQL'
-- Create sample application tables
CREATE TABLE users (
    user_id NUMBER GENERATED ALWAYS AS IDENTITY,
    username VARCHAR2(50) UNIQUE NOT NULL,
    email VARCHAR2(255) UNIQUE NOT NULL,
    created_date DATE DEFAULT SYSDATE,
    CONSTRAINT users_pk PRIMARY KEY (user_id)
);

CREATE TABLE sessions (
    session_id VARCHAR2(128) PRIMARY KEY,
    user_id NUMBER NOT NULL,
    created_date DATE DEFAULT SYSDATE,
    expires_date DATE NOT NULL,
    CONSTRAINT sessions_users_fk FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Create indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_expires ON sessions(expires_date);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON sessions TO app_user;

COMMIT;
EXIT;
SQL
EOF
```

#### 3. **Application Deployment Setup**

```bash
# Create deployment directory structure
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
mkdir -p ~/deployments/{staging,production}
mkdir -p ~/configs/{nginx,supervisor}
mkdir -p ~/logs/{app,nginx,system}

# Create deployment script template
cat > ~/scripts/deploy_app.sh << 'EOL'
#!/bin/bash
# Application deployment script template

APP_NAME="your-app-name"
ENVIRONMENT=${1:-staging}
GIT_REPO="https://github.com/your-org/your-repo.git"
DEPLOY_DIR="/home/ubuntu/deployments/$ENVIRONMENT"

echo "Deploying $APP_NAME to $ENVIRONMENT environment..."

# Pull latest code
if [ -d "$DEPLOY_DIR/.git" ]; then
    cd $DEPLOY_DIR
    git pull origin main
else
    git clone $GIT_REPO $DEPLOY_DIR
    cd $DEPLOY_DIR
fi

# Install dependencies
if [ -f "requirements.txt" ]; then
    source ~/venv/oracle-app/bin/activate
    pip install -r requirements.txt
elif [ -f "package.json" ]; then
    npm install
fi

# Run tests
if [ -f "run_tests.sh" ]; then
    ./run_tests.sh
fi

# Restart services (customize as needed)
# sudo systemctl restart your-app

echo "Deployment completed successfully!"
EOL

chmod +x ~/scripts/deploy_app.sh
EOF
```

#### 4. **Backup Configuration**

```bash
# Set up automated backups
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
# Create backup script
cat > ~/scripts/backup_data.sh << 'EOL'
#!/bin/bash
# Data backup script

BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup application data
tar -czf $BACKUP_DIR/app_data_$DATE.tar.gz ~/projects ~/configs 2>/dev/null

# Backup logs (last 7 days)
find ~/logs -name "*.log" -mtime -7 | tar -czf $BACKUP_DIR/logs_$DATE.tar.gz -T -

# Clean up old backups (keep last 30 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/*_$DATE.tar.gz"
EOL

chmod +x ~/scripts/backup_data.sh

# Schedule daily backups
(crontab -l 2>/dev/null; echo "0 2 * * * ~/scripts/backup_data.sh >> ~/logs/backup.log 2>&1") | crontab -
EOF
```

#### 5. **Security Audit Configuration**

```bash
# Set up security monitoring
ssh ubuntu@$(terraform output -raw instance_public_ip) << 'EOF'
# Install security tools
sudo apt-get install -y fail2ban lynis

# Configure fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Create security audit script
cat > ~/scripts/security_audit.sh << 'EOL'
#!/bin/bash
# Security audit script

echo "=== Security Audit Report ==="
echo "Date: $(date)"
echo

# Check for failed login attempts
echo "Failed SSH attempts (last 24 hours):"
grep "Failed password" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l

# Check active connections
echo "\nActive network connections:"
netstat -tuln | grep LISTEN

# Check for suspicious processes
echo "\nProcess list:"
ps aux --sort=-%cpu | head -5

# Check disk usage
echo "\nDisk usage:"
df -h | grep -v tmpfs

echo "\n=== End Security Audit ==="
EOL

chmod +x ~/scripts/security_audit.sh

# Schedule weekly security audits
(crontab -l 2>/dev/null; echo "0 6 * * 0 ~/scripts/security_audit.sh >> ~/logs/security_audit.log 2>&1") | crontab -
EOF
```

### Manual Verification Steps

#### Post-Deployment Checklist

1. **[ ] Infrastructure Verification**
   - [ ] All Terraform resources deployed successfully
   - [ ] Instance accessible via SSH
   - [ ] Database available and responding
   - [ ] Network security groups configured correctly
   - [ ] Block storage attached and mounted

2. **[ ] Application Environment**
   - [ ] Oracle Instant Client installed and configured
   - [ ] Python environment with cx_Oracle working
   - [ ] Node.js environment with oracledb working
   - [ ] Database wallet configured with proper permissions
   - [ ] Environment variables set correctly

3. **[ ] Security Configuration**
   - [ ] SSH key authentication working
   - [ ] Database passwords meet complexity requirements
   - [ ] Network access restricted as intended
   - [ ] Wallet files have restrictive permissions (600)
   - [ ] Fail2ban configured and active

4. **[ ] Monitoring and Logging**
   - [ ] System monitoring scripts deployed
   - [ ] Database health checks configured
   - [ ] Log rotation configured
   - [ ] Backup procedures implemented
   - [ ] Cron jobs scheduled correctly

5. **[ ] Application Readiness**
   - [ ] Database schema created
   - [ ] Sample data inserted successfully
   - [ ] Application directories created
   - [ ] Deployment scripts prepared
   - [ ] SSL certificates configured (if applicable)

### Documentation Updates Required

After completing the manual steps, update the following documentation:

1. **Environment-Specific Configuration**: Document any custom configurations made for your specific environment
2. **Database Schema**: Document the database schema and any custom objects created
3. **Backup Procedures**: Document backup and recovery procedures
4. **Monitoring Alerts**: Document alert thresholds and notification procedures
5. **Troubleshooting Guide**: Add any environment-specific troubleshooting steps

### Next Steps

Once manual configuration is complete:

1. **Application Development**: Begin developing your application using the configured environment
2. **CI/CD Setup**: Configure continuous integration and deployment pipelines
3. **Production Hardening**: Apply additional security measures for production environments
4. **Performance Tuning**: Optimize database and application performance based on usage patterns
5. **Disaster Recovery**: Implement comprehensive backup and recovery procedures

## Initial Setup

1. Clone this repository:
```bash
git clone <repository-url>
cd terraform-oci
```

2. Create terraform.tfvars:
```hcl
region           = "your-region"
compartment_id   = "your-compartment-ocid"
tenancy_ocid     = "your-tenancy-ocid"
user_ocid        = "your-user-ocid"
fingerprint      = "your-api-key-fingerprint"
private_key_path = "~/.oci/oci_api_key.pem"
ssh_public_key   = "your-ssh-public-key"
instance_image_id = "ocid-of-ubuntu-image"

db_name           = "ORCL"
db_admin_password = "your-secure-password"
db_user_name      = "app_user"
db_user_password  = "your-app-user-password"
wallet_password   = "your-wallet-password"
```

3. Initialize and apply Terraform:
```bash
terraform init
terraform plan
terraform apply
```

4. Set up the instance:
```bash
./scripts/setup_instance.sh $(terraform output -raw instance_public_ip)
```

## Instance Configuration

The compute instance is configured with:
- Public IP for easy access
- Oracle Instant Client
- Python with cx_Oracle
- Node.js with oracledb
- Proper wallet configuration
- Environment variables set

### Accessing the Instance

```bash
ssh ubuntu@$(terraform output -raw instance_public_ip)
```

### Environment Variables
```bash
export TNS_ADMIN=$HOME/.oracle/wallet/ORCL
export ORACLE_HOME=/usr/lib/oracle/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
```

## Database Access

### Python Examples

1. Basic Connection:
```python
import cx_Oracle
import os
from dotenv import load_dotenv

load_dotenv()

connection = cx_Oracle.connect(
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD'),
    dsn='ORCL_high',
    config_dir=os.getenv('TNS_ADMIN')
)

with connection.cursor() as cursor:
    cursor.execute('SELECT SYSDATE FROM DUAL')
    result = cursor.fetchone()
    print(f'Database time: {result[0]}')
```

2. CRUD Operations:
```python
from contextlib import contextmanager

@contextmanager
def get_connection():
    connection = None
    try:
        connection = cx_Oracle.connect(
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            dsn='ORCL_high',
            config_dir=os.getenv('TNS_ADMIN')
        )
        yield connection
    finally:
        if connection:
            connection.close()

def create_user(name: str, email: str):
    with get_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            'INSERT INTO users (name, email) VALUES (:1, :2)',
            [name, email]
        )
        connection.commit()
        return cursor.lastrowid
```

### TypeScript Examples

1. Basic Connection:
```typescript
import oracledb from 'oracledb';
import dotenv from 'dotenv';

dotenv.config();

async function connectToDatabase() {
    let connection;
    try {
        connection = await oracledb.getConnection({
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
            connectString: 'ORCL_high',
            configDir: process.env.TNS_ADMIN
        });

        const result = await connection.execute('SELECT SYSDATE FROM DUAL');
        console.log('Database time:', result.rows?.[0]);
    } finally {
        if (connection) {
            await connection.close();
        }
    }
}
```

2. Connection Pool:
```typescript
import oracledb, { Connection, Pool } from 'oracledb';

class DatabasePool {
    private static pool: Pool | null = null;

    static async initialize(): Promise<Pool> {
        if (!this.pool) {
            this.pool = await oracledb.createPool({
                user: process.env.DB_USER,
                password: process.env.DB_PASSWORD,
                connectString: 'ORCL_high',
                configDir: process.env.TNS_ADMIN,
                poolMin: 2,
                poolMax: 5,
                poolIncrement: 1
            });
        }
        return this.pool;
    }

    static async getConnection(): Promise<Connection> {
        if (!this.pool) {
            await this.initialize();
        }
        return await this.pool!.getConnection();
    }

    static async close(): Promise<void> {
        if (this.pool) {
            await this.pool.close(0);
            this.pool = null;
        }
    }
}

// Usage example
async function createUser(name: string, email: string): Promise<number> {
    const connection = await DatabasePool.getConnection();
    try {
        const result = await connection.execute(
            'INSERT INTO users (name, email) VALUES (:1, :2) RETURNING id INTO :3',
            [name, email, { type: oracledb.NUMBER, dir: oracledb.BIND_OUT }]
        );
        await connection.commit();
        return result.outBinds[0][0];
    } finally {
        await connection.close();
    }
}
```

3. Transaction Example:
```typescript
import { Connection } from 'oracledb';

async function transferMoney(
    fromAccount: string,
    toAccount: string,
    amount: number
): Promise<void> {
    const connection = await DatabasePool.getConnection();
    try {
        await connection.execute('BEGIN');

        // Debit from account
        await connection.execute(
            'UPDATE accounts SET balance = balance - :1 WHERE account_id = :2',
            [amount, fromAccount]
        );

        // Credit to account
        await connection.execute(
            'UPDATE accounts SET balance = balance + :1 WHERE account_id = :2',
            [amount, toAccount]
        );

        await connection.execute('COMMIT');
    } catch (error) {
        await connection.execute('ROLLBACK');
        throw error;
    } finally {
        await connection.close();
    }
}
```

### Other Methods

1. SQLPlus:
```bash
sqlplus app_user@ORCL_high
```

2. JDBC:
```java
String url = "jdbc:oracle:thin:@ORCL_high?TNS_ADMIN=/home/ubuntu/.oracle/wallet/ORCL";
Connection conn = DriverManager.getConnection(url, "app_user", "your_password");
```

## Security Considerations

1. Wallet Management:
   - Keep wallet files secure
   - Use proper file permissions (600)
   - Never commit wallet files to version control

2. Password Handling:
   - Use environment variables
   - Never hardcode passwords
   - Rotate passwords regularly

3. Network Security:
   - Restrict IP ranges in security lists
   - Use NSGs for fine-grained control
   - Keep ports closed unless needed

## Best Practices

1. Connection Management:
   - Use connection pooling
   - Close connections properly
   - Handle errors appropriately

2. Error Handling:
   - Implement proper try-catch blocks
   - Log errors appropriately
   - Use transactions where needed

3. Resource Management:
   - Monitor instance metrics
   - Watch database performance
   - Clean up unused resources

## Troubleshooting

1. Connection Issues:
   - Check wallet configuration
   - Verify TNS_ADMIN setting
   - Confirm security list rules

2. Performance Issues:
   - Check connection pooling
   - Monitor resource usage
   - Review query execution plans

3. Instance Access:
   - Verify SSH key configuration
   - Check security list rules
   - Confirm instance state

This guide explains how to access the Oracle Autonomous Database programmatically, with a focus on Python integration.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Environment Configuration](#environment-configuration)
- [Python Examples](#python-examples)
  - [Basic Connection](#basic-connection)
  - [Data Operations](#data-operations)
  - [Error Handling](#error-handling)
  - [Connection Pooling](#connection-pooling)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Prerequisites

1. Oracle Instant Client (for Linux):
```bash
# Add Oracle's repository
sudo bash -c 'echo "deb [arch=$(dpkg --print-architecture)] https://download.oracle.com/linux/oracle/deb/ stable main" > /etc/apt/sources.list.d/oracle-database.list'
sudo apt-get update
sudo apt-get install oracle-instantclient-basic oracle-instantclient-sqlplus

# Set environment variables
echo 'export LD_LIBRARY_PATH=/usr/lib/oracle/client64/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
echo 'export ORACLE_HOME=/usr/lib/oracle/client64' >> ~/.bashrc
source ~/.bashrc
```

2. Python packages:
```bash
pip install cx-Oracle python-dotenv
```

## Initial Setup

1. Set up the wallet:
```bash
# Run the setup script
./setup_db_connection.sh
```

2. Configure environment variables:
```bash
export TNS_ADMIN=$HOME/.oracle/wallet/ORCL
export ORACLE_HOME=/usr/lib/oracle/client64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
```

## TypeScript Examples

### Prerequisites

1. Install Node.js and npm
2. Install TypeScript globally:
```bash
npm install -g typescript
```

### Setup TypeScript Project

1. Install dependencies:
```bash
cd examples/typescript
npm install
```

2. Configure environment:
```bash
cp .env.template .env
# Edit .env with your credentials
```

3. Build and run:
```bash
npm run build
npm start
```

Or run directly with ts-node:
```bash
npm run dev
```

### TypeScript Example Code

```typescript
// Database connection setup
import oracledb from 'oracledb';

interface DatabaseConfig {
  user: string;
  password: string;
  connectString: string;
}

async function getConnection(config: DatabaseConfig) {
  try {
    const connection = await oracledb.getConnection({
      user: config.user,
      password: config.password,
      connectString: config.connectString
    });
    console.log('Connected to database');
    return connection;
  } catch (error) {
    console.error('Error connecting to database:', error);
    throw error;
  }
}

// Example query with parameters
async function getOrderById(orderId: number) {
  const connection = await getConnection(dbConfig);
  try {
    const result = await connection.execute(
      `SELECT * FROM orders WHERE order_id = :id`,
      { id: orderId },
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );
    return result.rows?.[0] || null;
  } finally {
    await connection.close();
  }
}

// Example transaction
async function createOrderWithItems(order: Order, items: OrderItem[]) {
  const connection = await getConnection(dbConfig);
  try {
    await connection.execute('BEGIN');

    // Insert order
    const orderResult = await connection.execute(
      `INSERT INTO orders (customer_id, order_date) 
       VALUES (:customer_id, SYSDATE) 
       RETURNING order_id INTO :order_id`,
      {
        customer_id: order.customerId,
        order_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
      }
    );

    const orderId = orderResult.outBinds.order_id[0];

    // Insert items
    for (const item of items) {
      await connection.execute(
        `INSERT INTO order_items (order_id, product_id, quantity) 
         VALUES (:order_id, :product_id, :quantity)`,
        {
          order_id: orderId,
          product_id: item.productId,
          quantity: item.quantity
        }
      );
    }

    await connection.execute('COMMIT');
    return orderId;
  } catch (error) {
    await connection.execute('ROLLBACK');
    throw error;
  } finally {
    await connection.close();
  }
}
```

## Python Examples

### Basic Connection

```python
import cx_Oracle
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database credentials
username = "ADMIN"
password = os.getenv("DB_PASSWORD")
dsn = "ORCL_high"  # Use high, medium, or low service

def get_connection():
    """Create and return a database connection"""
    try:
        connection = cx_Oracle.connect(
            user=username,
            password=password,
            dsn=dsn,
            config_dir=os.getenv("TNS_ADMIN")
        )
        print("Successfully connected to Oracle Database")
        return connection
    except cx_Oracle.Error as error:
        print(f"Error connecting to the database: {error}")
        raise

# Example usage
try:
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute("SELECT SYSDATE FROM DUAL")
    result = cursor.fetchone()
    print(f"Current database time: {result[0]}")
finally:
    if 'cursor' in locals():
        cursor.close()
    if 'connection' in locals():
        connection.close()
```

### Data Operations

```python
import cx_Oracle
from contextlib import contextmanager

@contextmanager
def database_connection():
    """Context manager for database connections"""
    connection = None
    try:
        connection = cx_Oracle.connect(
            user="ADMIN",
            password=os.getenv("DB_PASSWORD"),
            dsn="ORCL_high",
            config_dir=os.getenv("TNS_ADMIN")
        )
        yield connection
    finally:
        if connection:
            connection.close()

# Example: Create a table
def create_example_table():
    with database_connection() as connection:
        cursor = connection.cursor()
        cursor.execute("""
            CREATE TABLE customers (
                customer_id NUMBER GENERATED ALWAYS AS IDENTITY,
                name VARCHAR2(100),
                email VARCHAR2(255),
                created_date DATE DEFAULT SYSDATE,
                CONSTRAINT customers_pk PRIMARY KEY (customer_id)
            )
        """)
        print("Table created successfully")

# Example: Insert data
def insert_customer(name, email):
    with database_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO customers (name, email) VALUES (:1, :2)",
            (name, email)
        )
        connection.commit()
        return cursor.lastrowid

# Example: Query data
def get_customer(customer_id):
    with database_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT * FROM customers WHERE customer_id = :1",
            [customer_id]
        )
        columns = [col[0] for col in cursor.description]
        result = cursor.fetchone()
        return dict(zip(columns, result)) if result else None

# Example: Batch insert
def batch_insert_customers(customers):
    with database_connection() as connection:
        cursor = connection.cursor()
        cursor.executemany(
            "INSERT INTO customers (name, email) VALUES (:1, :2)",
            customers
        )
        connection.commit()
```

### Error Handling

```python
import cx_Oracle

class DatabaseError(Exception):
    """Custom exception for database errors"""
    pass

def safe_execute(query, params=None):
    """Execute a query with proper error handling"""
    with database_connection() as connection:
        try:
            cursor = connection.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            
            if query.strip().upper().startswith('SELECT'):
                columns = [col[0] for col in cursor.description]
                results = [dict(zip(columns, row)) for row in cursor.fetchall()]
                return results
            else:
                connection.commit()
                return cursor.rowcount
        except cx_Oracle.DatabaseError as e:
            error, = e.args
            raise DatabaseError(f"Oracle Error: {error.code} - {error.message}")
```

### Connection Pooling

```python
import cx_Oracle
from contextlib import contextmanager

class DatabasePool:
    _pool = None

    @classmethod
    def initialize(cls, min=2, max=5):
        """Initialize the connection pool"""
        try:
            cls._pool = cx_Oracle.SessionPool(
                user="ADMIN",
                password=os.getenv("DB_PASSWORD"),
                dsn="ORCL_high",
                min=min,
                max=max,
                increment=1,
                encoding="UTF-8",
                config_dir=os.getenv("TNS_ADMIN")
            )
            print(f"Connection pool created with {min} to {max} connections")
        except cx_Oracle.Error as error:
            print(f"Error creating connection pool: {error}")
            raise

    @classmethod
    @contextmanager
    def acquire(cls):
        """Acquire a connection from the pool"""
        if not cls._pool:
            cls.initialize()
        
        connection = cls._pool.acquire()
        try:
            yield connection
        finally:
            cls._pool.release(connection)

# Example usage with connection pool
def example_pool_usage():
    with DatabasePool.acquire() as connection:
        cursor = connection.cursor()
        cursor.execute("SELECT * FROM customers")
        results = cursor.fetchall()
        return results
```

## Best Practices

1. Always use connection pooling for applications
2. Use parameterized queries to prevent SQL injection
3. Handle database connections with context managers
4. Implement proper error handling
5. Close cursors and connections properly
6. Use connection pools for better performance
7. Keep sensitive information in environment variables

## Troubleshooting

Common issues and solutions:

1. **TNS:could not resolve service name**
   - Check if TNS_ADMIN is set correctly
   - Verify wallet files are in the correct location
   - Ensure tnsnames.ora contains the correct service name

2. **ORA-28759: failure to open file**
   - Check wallet permissions
   - Verify wallet location is correct
   - Ensure all wallet files are present

3. **ORA-01017: invalid username/password**
   - Verify ADMIN password is correct
   - Check if the database is running
   - Ensure you're using the correct service name

4. **DPI-1047: Cannot locate Oracle Client library**
   - Check if Oracle Instant Client is installed
   - Verify LD_LIBRARY_PATH is set correctly
   - Ensure ORACLE_HOME is set

For more help, check:
- [cx_Oracle documentation](https://cx-oracle.readthedocs.io/)
- [Oracle Autonomous Database documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/index.html)
- [Python Database Programming Guide](https://python.org/dev/peps/pep-0249/)

