# Security Guide

This document outlines the security features, configurations, and best practices for the OCI infrastructure deployment.

## Security Overview

The infrastructure implements a comprehensive security framework based on defense-in-depth principles:

- **Network Security**: Multi-layered network controls with VCN, Security Lists, and NSGs
- **Identity & Access**: Strong authentication with SSH keys and database wallets
- **Data Protection**: Encryption in transit and at rest for all data
- **Monitoring**: Comprehensive logging and alerting for security events
- **Compliance**: Security configurations aligned with industry best practices

## Network Security

### Virtual Cloud Network (VCN) Security

#### Network Segmentation
- **VCN Isolation**: Complete network isolation from other tenancies
- **Subnet Separation**: Logical separation between database and application tiers
- **CIDR Planning**: Non-overlapping address spaces for future expansion

```
VCN: 10.0.0.0/16
├── Database Subnet: 10.0.1.0/24 (Private tier)
└── Instance Subnet: 10.0.2.0/24 (Public tier)
```

#### Internet Access Control
- **Internet Gateway**: Controlled public internet access
- **Route Tables**: Explicit routing rules for traffic flow
- **NAT Gateway**: (Optional) For private subnet internet access

### Security Lists (Traditional Firewall)

#### Database Security List
**Purpose**: Control access to database resources

**Inbound Rules**:
```
Protocol: TCP, Port: 1521, Source: Instance Subnet (10.0.2.0/24)
Protocol: TCP, Port: 443, Source: 0.0.0.0/0 (HTTPS for management)
```

**Outbound Rules**:
```
Protocol: All, Destination: 0.0.0.0/0 (Allow all outbound)
```

#### Instance Security List
**Purpose**: Control access to compute instances

**Inbound Rules**:
```
Protocol: TCP, Port: 22, Source: Configurable (SSH access)
Protocol: TCP, Port: 80, Source: 0.0.0.0/0 (HTTP applications)
Protocol: TCP, Port: 443, Source: 0.0.0.0/0 (HTTPS applications)
```

**Outbound Rules**:
```
Protocol: All, Destination: 0.0.0.0/0 (Allow all outbound)
```

### Network Security Groups (Application-Level)

#### SSH Security Group
**Purpose**: Granular SSH access control

```hcl
# SSH access rule - restrict in production
resource "oci_core_network_security_group_security_rule" "ssh_ingress" {
  direction = "INGRESS"
  protocol  = "6" # TCP
  source    = var.allowed_ssh_cidr # Default: 0.0.0.0/0 - CHANGE THIS!
  
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}
```

**Security Recommendation**: Restrict `allowed_ssh_cidr` to specific IP ranges:
```hcl
allowed_ssh_cidr = "203.0.113.0/24"  # Your office/home network
```

#### Web Security Group
**Purpose**: HTTP/HTTPS traffic management

```hcl
# HTTPS traffic (recommended)
resource "oci_core_network_security_group_security_rule" "https_ingress" {
  direction = "INGRESS"
  protocol  = "6" # TCP
  source    = "0.0.0.0/0"
  
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}
```

#### Database Security Group
**Purpose**: Database connectivity control

```hcl
# Database access from instance subnet only
resource "oci_core_network_security_group_security_rule" "database_security_rule" {
  direction = "INGRESS"
  protocol  = "6" # TCP
  source    = oci_core_subnet.instance_subnet.cidr_block
  
  tcp_options {
    destination_port_range {
      min = 1522  # Autonomous Database port
      max = 1522
    }
  }
}
```

## Identity and Access Management

### SSH Key Authentication

#### Key Management
- **No Password Authentication**: Password-based SSH disabled by default
- **Public Key Authentication**: Only authorized SSH keys permitted
- **Key Rotation**: Regular key rotation recommended

#### SSH Configuration
```bash
# Disable password authentication
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
MaxAuthTries 3
```

#### Best Practices
1. **Use Strong Keys**: RSA 4096-bit or Ed25519 keys
2. **Protect Private Keys**: Secure storage with passphrase protection
3. **Limit Key Distribution**: Minimal key distribution
4. **Regular Rotation**: Quarterly key rotation for production

### Database Authentication

#### Wallet-Based Authentication
- **mTLS Encryption**: Mutual TLS for all database connections
- **Certificate-Based**: X.509 certificate authentication
- **No Clear-Text Passwords**: Passwords encrypted in wallet

#### Wallet Security
```bash
# Secure wallet file permissions
chmod 600 ~/.oracle/wallet/ORCL/*
chown ubuntu:ubuntu ~/.oracle/wallet/ORCL/*
```

#### Connection Security
```python
# Secure connection example
connection = cx_Oracle.connect(
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD'),
    dsn='ORCL_high',
    config_dir=os.getenv('TNS_ADMIN')  # Wallet location
)
```

### Database User Management

#### Principle of Least Privilege
- **Application User**: Dedicated non-admin user for applications
- **Limited Permissions**: Only CONNECT and RESOURCE roles
- **Schema Separation**: Application-specific schema isolation

#### User Configuration
```sql
-- Application user with minimal privileges
CREATE USER app_user IDENTIFIED BY secure_password;
GRANT CONNECT TO app_user;
GRANT RESOURCE TO app_user;
GRANT CREATE SESSION TO app_user;

-- Specific table permissions only
GRANT SELECT, INSERT, UPDATE, DELETE ON app_tables TO app_user;
```

## Data Protection

### Encryption in Transit

#### Database Connections
- **TLS 1.2+**: All database connections encrypted
- **Certificate Validation**: Server certificate validation enabled
- **Perfect Forward Secrecy**: Ephemeral key exchange

#### Web Traffic
- **HTTPS Enforcement**: SSL/TLS for all web communications
- **HSTS Headers**: HTTP Strict Transport Security
- **Certificate Management**: Let's Encrypt or commercial certificates

### Encryption at Rest

#### Database Storage
- **Autonomous Database**: Transparent Data Encryption (TDE) enabled
- **Automatic Key Management**: Oracle-managed encryption keys
- **Backup Encryption**: Encrypted automatic backups

#### Block Storage
- **Volume Encryption**: Block volume encryption available
- **Key Management**: OCI Key Management Service integration

## Security Monitoring and Logging

### OCI Native Monitoring

#### Logging Configuration
```hcl
# Centralized log group
resource "oci_logging_log_group" "security_logs" {
  compartment_id = var.compartment_id
  display_name   = "security-log-group"
}

# Instance security logs
resource "oci_logging_log" "security_log" {
  display_name = "security-events"
  log_group_id = oci_logging_log_group.security_logs.id
  log_type     = "SERVICE"
}
```

#### Monitored Events
- **Authentication Events**: SSH login attempts, database connections
- **Network Events**: Unusual traffic patterns, blocked connections
- **System Events**: File access, privilege escalation attempts
- **Application Events**: Application-specific security events

### Security Alerting

#### Critical Alerts
1. **Failed Authentication**: Multiple failed SSH/database login attempts
2. **Privilege Escalation**: sudo usage, root access attempts
3. **Network Anomalies**: Unusual traffic patterns or volumes
4. **File Integrity**: Changes to critical system files
5. **Resource Exhaustion**: CPU/memory/disk usage spikes

#### Alert Configuration
```bash
# Example: Monitor failed SSH attempts
#!/bin/bash
FAILED_ATTEMPTS=$(grep "Failed password" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l)
if [ $FAILED_ATTEMPTS -gt 10 ]; then
    echo "ALERT: $FAILED_ATTEMPTS failed SSH attempts today" | logger -p local0.warning
fi
```

### Log Management

#### Log Retention
- **System Logs**: 90 days minimum
- **Security Logs**: 1 year minimum
- **Audit Logs**: 7 years (compliance dependent)
- **Application Logs**: 30 days minimum

#### Log Protection
- **Immutable Storage**: Write-once, read-many log storage
- **Access Controls**: Role-based access to log data
- **Integrity Checking**: Log file integrity validation

## Security Best Practices

### Password Management

#### Password Policies
- **Minimum Length**: 12 characters minimum
- **Complexity**: Upper, lower, numbers, special characters
- **No Dictionary Words**: Avoid common passwords
- **Regular Rotation**: 90-day rotation for service accounts

#### Secure Storage
```bash
# Environment variables for passwords
export DB_PASSWORD=$(vault read -field=password secret/database)
export WALLET_PASSWORD=$(vault read -field=password secret/wallet)
```

#### Password Examples (Compliant)
```
# Strong password examples:
SecurePass123#$
MyApp2024!Strong
ComplexP@ssw0rd
```

### Network Hardening

#### SSH Hardening
```bash
# /etc/ssh/sshd_config hardening
Protocol 2
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
PermitEmptyPasswords no
X11Forwarding no
MaxStartups 3:30:10
```

#### Firewall Configuration
```bash
# UFW (Uncomplicated Firewall) setup
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 203.0.113.0/24 to any port 22  # Specific SSH access
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

#### Network Monitoring
```bash
# Monitor network connections
netstat -tuln | grep LISTEN
ss -tuln | grep LISTEN

# Monitor unusual traffic
sudo iftop -i eth0
sudo nethogs eth0
```

### Application Security

#### Secure Coding Practices
1. **Input Validation**: Validate all user inputs
2. **SQL Injection Prevention**: Use parameterized queries
3. **XSS Prevention**: Escape output, use CSP headers
4. **CSRF Protection**: Anti-CSRF tokens
5. **Session Management**: Secure session handling

#### Database Security
```python
# Secure database connection with parameterized queries
def get_user(user_id):
    with get_connection() as conn:
        cursor = conn.cursor()
        # Use parameterized query to prevent SQL injection
        cursor.execute(
            "SELECT * FROM users WHERE user_id = :user_id",
            {"user_id": user_id}
        )
        return cursor.fetchone()
```

### System Hardening

#### OS Hardening
```bash
# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups
sudo systemctl disable avahi-daemon

# Set file permissions
sudo chmod 644 /etc/passwd
sudo chmod 600 /etc/shadow
sudo chmod 644 /etc/group

# Remove unnecessary packages
sudo apt-get autoremove
sudo apt-get autoclean
```

#### File System Security
```bash
# Secure mount options in /etc/fstab
/dev/sda1 / ext4 defaults,nodev,nosuid,noexec 0 1
tmpfs /tmp tmpfs defaults,nodev,nosuid,noexec 0 0
```

## Compliance and Standards

### Security Frameworks

#### CIS Benchmarks
- **Ubuntu 20.04 CIS Benchmark**: Level 1 controls implemented
- **Oracle Database CIS**: Database-specific security controls
- **Network Security**: CIS network security guidelines

#### NIST Framework
- **Identify**: Asset inventory and risk assessment
- **Protect**: Security controls implementation
- **Detect**: Monitoring and detection capabilities
- **Respond**: Incident response procedures
- **Recover**: Recovery and continuity planning

### Regulatory Compliance

#### Data Protection
- **GDPR**: Data protection and privacy controls
- **CCPA**: California Consumer Privacy Act compliance
- **SOX**: Sarbanes-Oxley financial controls
- **HIPAA**: Healthcare data protection (if applicable)

#### Industry Standards
- **ISO 27001**: Information security management
- **SOC 2**: Service organization controls
- **PCI DSS**: Payment card industry standards (if applicable)

## Incident Response

### Security Incident Categories

#### High Severity
1. **Data Breach**: Unauthorized access to sensitive data
2. **System Compromise**: Root/admin access gained
3. **Service Disruption**: Security-related service outage
4. **Malware Detection**: Malicious software identified

#### Medium Severity
1. **Failed Authentication**: Repeated failed login attempts
2. **Policy Violation**: Security policy violations
3. **Vulnerability**: New security vulnerabilities identified
4. **Suspicious Activity**: Unusual but not confirmed malicious activity

### Response Procedures

#### Immediate Response (0-1 hours)
1. **Assess Impact**: Determine scope and severity
2. **Contain Threat**: Isolate affected systems
3. **Preserve Evidence**: Capture logs and forensic data
4. **Notify Stakeholders**: Alert relevant teams and management

#### Investigation (1-24 hours)
1. **Root Cause Analysis**: Determine how incident occurred
2. **Evidence Collection**: Gather additional forensic evidence
3. **Impact Assessment**: Full impact and data exposure analysis
4. **External Notifications**: Regulatory and customer notifications

#### Recovery (24-72 hours)
1. **System Restoration**: Restore systems from clean backups
2. **Security Patches**: Apply necessary security updates
3. **Access Review**: Review and update access controls
4. **Monitoring Enhancement**: Improve detection capabilities

## Security Testing

### Vulnerability Assessment

#### Automated Scanning
```bash
# System vulnerability scanning
sudo apt-get install lynis
sudo lynis audit system

# Network vulnerability scanning
nmap -sS -O target_host
nmap --script vuln target_host
```

#### Manual Testing
1. **SSH Configuration**: Test SSH hardening measures
2. **Database Security**: Test database access controls
3. **Network Segmentation**: Verify network isolation
4. **Application Security**: Test web application security

### Penetration Testing

#### External Testing
- **Network Perimeter**: External network security testing
- **Web Applications**: Application security assessment
- **Social Engineering**: Phishing and social engineering tests

#### Internal Testing
- **Lateral Movement**: Internal network movement testing
- **Privilege Escalation**: Local privilege escalation testing
- **Data Access**: Unauthorized data access attempts

### Security Metrics

#### Key Performance Indicators
1. **Mean Time to Detection (MTTD)**: Average time to detect incidents
2. **Mean Time to Response (MTTR)**: Average time to respond to incidents
3. **Vulnerability Remediation Time**: Time to patch vulnerabilities
4. **Security Training Completion**: Staff security training metrics

#### Monitoring Dashboards
```bash
# Security dashboard metrics
- Failed authentication attempts: Daily count
- System vulnerabilities: Open/closed counts
- Security patches: Applied/pending counts
- Compliance score: Percentage compliance
```

## Security Contacts

### Internal Contacts
- **Security Team**: security@organization.com
- **Infrastructure Team**: infrastructure@organization.com
- **Compliance Team**: compliance@organization.com

### External Contacts
- **Oracle Security**: https://www.oracle.com/security-alerts/
- **Ubuntu Security**: https://ubuntu.com/security/notices
- **CERT**: https://www.cert.org/

### Emergency Procedures
1. **High Severity Incidents**: Call security hotline immediately
2. **Data Breach**: Follow data breach notification procedures
3. **System Compromise**: Isolate systems and contact security team
4. **External Threats**: Contact law enforcement if necessary

---

This security guide should be reviewed and updated regularly to maintain current security posture and address evolving threats.

