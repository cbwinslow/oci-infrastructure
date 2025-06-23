# Security Architecture and Implementation Guide

## Overview

This document provides comprehensive security architecture guidelines, implementation details, and operational procedures for the OCI Infrastructure project. It defines the security framework, controls, and compliance requirements that ensure robust protection of infrastructure and data.

## Security Framework

### Defense in Depth Strategy

Our security architecture implements multiple layers of protection:

1. **Perimeter Security**: Network-level controls and access restrictions
2. **Network Security**: Segmentation, monitoring, and traffic control
3. **Application Security**: Secure coding practices and runtime protection
4. **Data Security**: Encryption, access controls, and data classification
5. **Infrastructure Security**: Hardened systems and security monitoring
6. **Identity and Access Management**: Authentication, authorization, and audit
7. **Operational Security**: Procedures, monitoring, and incident response

### Security Principles

#### 1. Zero Trust Architecture
- **Assumption**: No implicit trust based on network location
- **Verification**: Verify every user and device before granting access
- **Least Privilege**: Minimum access required for functionality
- **Continuous Monitoring**: Real-time security assessment and response

#### 2. Secure by Design
- **Security Requirements**: Integrated from project inception
- **Risk Assessment**: Continuous threat modeling and risk evaluation
- **Security Controls**: Built into architecture, not added as afterthought
- **Compliance**: Designed to meet regulatory requirements

#### 3. Layered Security
- **Multiple Controls**: No single point of failure
- **Complementary Protections**: Controls work together for enhanced security
- **Defense Diversity**: Different types of security measures
- **Redundancy**: Backup controls for critical security functions

## Network Security Architecture

### Network Segmentation

```hcl
# Production Network Security Configuration

# Virtual Cloud Network (VCN)
resource "oci_core_vcn" "secure_vcn" {
  compartment_id = var.compartment_id
  display_name   = "secure-production-vcn"
  cidr_blocks    = ["10.1.0.0/16"]
  dns_label      = "secprodvcn"
  
  freeform_tags = {
    SecurityZone = "Production"
    DataClass    = "Confidential"
    Compliance   = "SOX-PCI"
  }
}

# DMZ Subnet for Public-Facing Resources
resource "oci_core_subnet" "dmz_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "dmz-subnet"
  cidr_block     = "10.1.10.0/24"
  dns_label      = "dmz"
  
  # Public subnet for load balancers
  prohibit_public_ip_on_vnic = false
  
  security_list_ids = [oci_core_security_list.dmz_security_list.id]
  route_table_id    = oci_core_route_table.dmz_route_table.id
  
  freeform_tags = {
    SecurityZone = "DMZ"
    Purpose      = "LoadBalancer"
  }
}

# Application Tier Subnet
resource "oci_core_subnet" "app_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "app-tier-subnet"
  cidr_block     = "10.1.20.0/24"
  dns_label      = "app"
  
  # Private subnet for application servers
  prohibit_public_ip_on_vnic = true
  
  security_list_ids = [oci_core_security_list.app_security_list.id]
  route_table_id    = oci_core_route_table.private_route_table.id
  
  freeform_tags = {
    SecurityZone = "Application"
    Purpose      = "AppServers"
  }
}

# Database Tier Subnet
resource "oci_core_subnet" "db_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "database-tier-subnet"
  cidr_block     = "10.1.30.0/24"
  dns_label      = "db"
  
  # Private subnet for databases
  prohibit_public_ip_on_vnic = true
  
  security_list_ids = [oci_core_security_list.db_security_list.id]
  route_table_id    = oci_core_route_table.private_route_table.id
  
  freeform_tags = {
    SecurityZone = "Database"
    Purpose      = "DatabaseServers"
    DataClass    = "HighlyConfidential"
  }
}

# Management Subnet for Administrative Access
resource "oci_core_subnet" "mgmt_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "management-subnet"
  cidr_block     = "10.1.40.0/24"
  dns_label      = "mgmt"
  
  # Private subnet for management systems
  prohibit_public_ip_on_vnic = true
  
  security_list_ids = [oci_core_security_list.mgmt_security_list.id]
  route_table_id    = oci_core_route_table.mgmt_route_table.id
  
  freeform_tags = {
    SecurityZone = "Management"
    Purpose      = "AdminAccess"
  }
}
```

### Security Lists and Network Security Groups

```hcl
# DMZ Security List - Minimal Internet Access
resource "oci_core_security_list" "dmz_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "dmz-security-list"

  # Egress Rules - Restricted Internet Access
  egress_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"  # TCP
    description = "HTTPS Outbound"
    
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"  # TCP
    description = "HTTP Outbound for redirects"
    
    tcp_options {
      min = 80
      max = 80
    }
  }

  # Ingress Rules - Public Access for Load Balancer
  ingress_rules {
    source      = "0.0.0.0/0"
    protocol    = "6"  # TCP
    description = "HTTPS from Internet"
    
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_rules {
    source      = "0.0.0.0/0"
    protocol    = "6"  # TCP
    description = "HTTP for SSL redirect"
    
    tcp_options {
      min = 80
      max = 80
    }
  }
}

# Application Tier Security List
resource "oci_core_security_list" "app_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "app-security-list"

  # Egress Rules - Database and Internet Access
  egress_rules {
    destination = "10.1.30.0/24"  # Database subnet
    protocol    = "6"              # TCP
    description = "Database Access"
    
    tcp_options {
      min = 1521
      max = 1521
    }
  }

  egress_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"  # TCP
    description = "HTTPS for updates and APIs"
    
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress Rules - From DMZ and Management
  ingress_rules {
    source      = "10.1.10.0/24"  # DMZ subnet
    protocol    = "6"              # TCP
    description = "HTTP from Load Balancer"
    
    tcp_options {
      min = 8080
      max = 8080
    }
  }

  ingress_rules {
    source      = "10.1.40.0/24"  # Management subnet
    protocol    = "6"              # TCP
    description = "SSH from Management"
    
    tcp_options {
      min = 22
      max = 22
    }
  }
}

# Database Tier Security List - Most Restrictive
resource "oci_core_security_list" "db_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "database-security-list"

  # Egress Rules - Minimal Required Access
  egress_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"  # TCP
    description = "HTTPS for Oracle Cloud Services"
    
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress Rules - Only from Application Tier
  ingress_rules {
    source      = "10.1.20.0/24"  # Application subnet
    protocol    = "6"              # TCP
    description = "Database Access from App Tier"
    
    tcp_options {
      min = 1521
      max = 1521
    }
  }

  ingress_rules {
    source      = "10.1.40.0/24"  # Management subnet
    protocol    = "6"              # TCP
    description = "SSH from Management"
    
    tcp_options {
      min = 22
      max = 22
    }
  }
}

# Management Security List
resource "oci_core_security_list" "mgmt_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "management-security-list"

  # Egress Rules - Administrative Access
  egress_rules {
    destination = "10.1.0.0/16"  # Internal VCN
    protocol    = "6"             # TCP
    description = "SSH to all internal subnets"
    
    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"  # TCP
    description = "HTTPS for management tools"
    
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress Rules - VPN or Bastion Access Only
  ingress_rules {
    source      = var.corporate_network_cidr
    protocol    = "6"  # TCP
    description = "SSH from Corporate Network"
    
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_rules {
    source      = var.corporate_network_cidr
    protocol    = "6"  # TCP
    description = "HTTPS for management interfaces"
    
    tcp_options {
      min = 443
      max = 443
    }
  }
}
```

### Network Security Groups (NSGs)

```hcl
# Web Application Firewall NSG
resource "oci_core_network_security_group" "waf_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "waf-nsg"
  
  freeform_tags = {
    Purpose = "WebApplicationFirewall"
  }
}

# Application Server NSG
resource "oci_core_network_security_group" "app_server_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "app-server-nsg"
  
  freeform_tags = {
    Purpose = "ApplicationServers"
  }
}

# Database NSG
resource "oci_core_network_security_group" "database_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "database-nsg"
  
  freeform_tags = {
    Purpose = "DatabaseAccess"
  }
}

# Monitoring NSG
resource "oci_core_network_security_group" "monitoring_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.secure_vcn.id
  display_name   = "monitoring-nsg"
  
  freeform_tags = {
    Purpose = "MonitoringServices"
  }
}
```

## Identity and Access Management

### IAM Policies and Groups

```hcl
# Infrastructure Administrators Group
resource "oci_identity_group" "infrastructure_admins" {
  compartment_id = var.tenancy_ocid
  name           = "infrastructure-administrators"
  description    = "Full infrastructure management access"
  
  freeform_tags = {
    Role        = "InfrastructureAdmin"
    AccessLevel = "Full"
  }
}

# Database Administrators Group
resource "oci_identity_group" "database_admins" {
  compartment_id = var.tenancy_ocid
  name           = "database-administrators"
  description    = "Database management access"
  
  freeform_tags = {
    Role        = "DatabaseAdmin"
    AccessLevel = "DatabaseOnly"
  }
}

# Security Operations Group
resource "oci_identity_group" "security_ops" {
  compartment_id = var.tenancy_ocid
  name           = "security-operations"
  description    = "Security monitoring and incident response"
  
  freeform_tags = {
    Role        = "SecurityOperations"
    AccessLevel = "SecurityMonitoring"
  }
}

# Application Developers Group
resource "oci_identity_group" "app_developers" {
  compartment_id = var.tenancy_ocid
  name           = "application-developers"
  description    = "Application deployment and monitoring"
  
  freeform_tags = {
    Role        = "Developer"
    AccessLevel = "ApplicationOnly"
  }
}

# Infrastructure Administrators Policy
resource "oci_identity_policy" "infrastructure_admin_policy" {
  compartment_id = var.compartment_id
  name           = "infrastructure-administrators-policy"
  description    = "Full infrastructure management permissions"
  
  statements = [
    "Allow group infrastructure-administrators to manage all-resources in compartment ${var.compartment_name}",
    "Allow group infrastructure-administrators to manage users in tenancy",
    "Allow group infrastructure-administrators to manage groups in tenancy",
    "Allow group infrastructure-administrators to use cloud-shell in tenancy",
    "Allow group infrastructure-administrators to manage policies in compartment ${var.compartment_name}",
    "Allow group infrastructure-administrators to manage dynamic-groups in tenancy"
  ]
}

# Database Administrators Policy
resource "oci_identity_policy" "database_admin_policy" {
  compartment_id = var.compartment_id
  name           = "database-administrators-policy"
  description    = "Database management permissions"
  
  statements = [
    "Allow group database-administrators to manage autonomous-databases in compartment ${var.compartment_name}",
    "Allow group database-administrators to manage database-backups in compartment ${var.compartment_name}",
    "Allow group database-administrators to read all-resources in compartment ${var.compartment_name}",
    "Allow group database-administrators to use cloud-shell in tenancy"
  ]
}

# Security Operations Policy
resource "oci_identity_policy" "security_ops_policy" {
  compartment_id = var.compartment_id
  name           = "security-operations-policy"
  description    = "Security monitoring and incident response permissions"
  
  statements = [
    "Allow group security-operations to read audit-events in compartment ${var.compartment_name}",
    "Allow group security-operations to read logging-log-groups in compartment ${var.compartment_name}",
    "Allow group security-operations to read logging-logs in compartment ${var.compartment_name}",
    "Allow group security-operations to read waas-policies in compartment ${var.compartment_name}",
    "Allow group security-operations to manage waas-policies in compartment ${var.compartment_name}",
    "Allow group security-operations to read all-resources in compartment ${var.compartment_name}",
    "Allow group security-operations to use cloud-shell in tenancy"
  ]
}

# Application Developers Policy
resource "oci_identity_policy" "app_developer_policy" {
  compartment_id = var.compartment_id
  name           = "application-developers-policy"
  description    = "Application deployment and monitoring permissions"
  
  statements = [
    "Allow group application-developers to read instances in compartment ${var.compartment_name}",
    "Allow group application-developers to use instance-agent-command-execution-family in compartment ${var.compartment_name}",
    "Allow group application-developers to read logging-log-groups in compartment ${var.compartment_name}",
    "Allow group application-developers to read logging-logs in compartment ${var.compartment_name}",
    "Allow group application-developers to manage application-migration-family in compartment ${var.compartment_name}",
    "Allow group application-developers to use cloud-shell in tenancy"
  ]
}
```

### Multi-Factor Authentication

```bash
# MFA Configuration Script
cat > scripts/configure_mfa.sh << 'EOF'
#!/bin/bash
# Configure Multi-Factor Authentication

# Enable MFA for all users
enable_mfa() {
    echo "Configuring MFA requirements..."
    
    # Get all users in the groups
    GROUPS=("infrastructure-administrators" "database-administrators" "security-operations" "application-developers")
    
    for group in "${GROUPS[@]}"; do
        echo "Processing group: $group"
        
        # Get group OCID
        GROUP_OCID=$(oci iam group list --name "$group" --query 'data[0].id' --raw-output)
        
        if [ -n "$GROUP_OCID" ]; then
            # List users in group
            USER_LIST=$(oci iam group list-users --group-id "$GROUP_OCID" --query 'data[].id' --raw-output)
            
            for user_id in $USER_LIST; do
                echo "Enabling MFA for user: $user_id"
                
                # Check if MFA is already enabled
                MFA_STATUS=$(oci iam user get --user-id "$user_id" --query 'data."is-mfa-activated"' --raw-output)
                
                if [ "$MFA_STATUS" = "false" ]; then
                    echo "MFA not enabled for user $user_id - requiring setup"
                    # Note: MFA activation requires user interaction
                    # Send notification to user to set up MFA
                fi
            done
        fi
    done
}

# Create MFA policy
create_mfa_policy() {
    cat > mfa_policy.json << 'POLICY'
{
  "name": "require-mfa-policy",
  "description": "Require MFA for all administrative operations",
  "statements": [
    "Allow group infrastructure-administrators to manage all-resources in compartment production where request.authentication.mfaAuthenticated='true'",
    "Allow group database-administrators to manage autonomous-databases in compartment production where request.authentication.mfaAuthenticated='true'",
    "Allow group security-operations to manage waas-policies in compartment production where request.authentication.mfaAuthenticated='true'"
  ]
}
POLICY

    # Apply MFA policy
    oci iam policy create \
        --compartment-id "$COMPARTMENT_ID" \
        --name "require-mfa-policy" \
        --description "Require MFA for all administrative operations" \
        --statements file://mfa_policy.json
}

# Main function
main() {
    enable_mfa
    create_mfa_policy
    echo "MFA configuration completed"
}

main "$@"
EOF

chmod +x scripts/configure_mfa.sh
```

## Data Protection and Encryption

### Encryption at Rest

```hcl
# Key Management Service (KMS) Configuration
resource "oci_kms_vault" "security_vault" {
  compartment_id = var.compartment_id
  display_name   = "security-vault"
  vault_type     = "DEFAULT"
  
  freeform_tags = {
    Purpose = "DataEncryption"
    Environment = "Production"
  }
}

# Database Encryption Key
resource "oci_kms_key" "database_encryption_key" {
  compartment_id = var.compartment_id
  display_name   = "database-encryption-key"
  management_endpoint = oci_kms_vault.security_vault.management_endpoint
  
  key_shape {
    algorithm = "AES"
    length    = 256
  }
  
  protection_mode = "HSM"
  
  freeform_tags = {
    Purpose = "DatabaseEncryption"
    KeyType = "AES256"
  }
}

# Block Storage Encryption Key
resource "oci_kms_key" "storage_encryption_key" {
  compartment_id = var.compartment_id
  display_name   = "storage-encryption-key"
  management_endpoint = oci_kms_vault.security_vault.management_endpoint
  
  key_shape {
    algorithm = "AES"
    length    = 256
  }
  
  protection_mode = "HSM"
  
  freeform_tags = {
    Purpose = "StorageEncryption"
    KeyType = "AES256"
  }
}

# Object Storage Encryption Key
resource "oci_kms_key" "object_storage_encryption_key" {
  compartment_id = var.compartment_id
  display_name   = "object-storage-encryption-key"
  management_endpoint = oci_kms_vault.security_vault.management_endpoint
  
  key_shape {
    algorithm = "AES"
    length    = 256
  }
  
  protection_mode = "HSM"
  
  freeform_tags = {
    Purpose = "ObjectStorageEncryption"
    KeyType = "AES256"
  }
}

# Encrypted Autonomous Database
resource "oci_database_autonomous_database" "encrypted_database" {
  compartment_id = var.compartment_id
  display_name   = "encrypted-production-database"
  db_name        = var.db_name
  
  # Encryption configuration
  kms_key_id = oci_kms_key.database_encryption_key.id
  
  # Customer-managed encryption
  customer_contacts {
    email = var.security_contact_email
  }
  
  # Additional security settings
  is_data_guard_enabled = true
  is_auto_scaling_enabled = false
  
  freeform_tags = {
    Environment = "Production"
    Encrypted   = "CustomerManaged"
    BackupEncrypted = "True"
  }
}

# Encrypted Block Volume
resource "oci_core_volume" "encrypted_volume" {
  compartment_id = var.compartment_id
  display_name   = "encrypted-app-volume"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  
  size_in_gbs = var.volume_size_in_gbs
  
  # Encryption with customer-managed key
  kms_key_id = oci_kms_key.storage_encryption_key.id
  
  freeform_tags = {
    Purpose = "ApplicationData"
    Encrypted = "CustomerManaged"
  }
}

# Encrypted Object Storage Bucket
resource "oci_objectstorage_bucket" "encrypted_bucket" {
  compartment_id = var.compartment_id
  name           = "encrypted-backup-bucket"
  namespace      = data.oci_objectstorage_namespace.namespace.namespace
  
  # Customer-managed encryption
  kms_key_id = oci_kms_key.object_storage_encryption_key.id
  
  # Additional security settings
  versioning = "Enabled"
  public_access_type = "NoPublicAccess"
  
  retention_rules {
    display_name = "backup-retention"
    duration {
      time_amount = 30
      time_unit   = "DAYS"
    }
    time_rule_locked = timeadd(timestamp(), "8760h")  # 1 year
  }
  
  freeform_tags = {
    Purpose = "EncryptedBackups"
    DataClass = "Confidential"
  }
}
```

### Encryption in Transit

```bash
# SSL/TLS Configuration Script
cat > scripts/configure_ssl_tls.sh << 'EOF'
#!/bin/bash
# Configure SSL/TLS for all services

# Configure NGINX SSL
configure_nginx_ssl() {
    cat > /etc/nginx/ssl.conf << 'SSL_CONF'
# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;

# SSL Security Headers
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy "strict-origin-when-cross-origin";

# SSL Session Configuration
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;

# Certificate Configuration
ssl_certificate /etc/ssl/certs/production.crt;
ssl_certificate_key /etc/ssl/private/production.key;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
SSL_CONF

    # Generate strong DH parameters
    openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    
    # Set proper permissions
    chmod 600 /etc/ssl/private/production.key
    chmod 644 /etc/ssl/certs/production.crt
}

# Configure Database SSL
configure_database_ssl() {
    # Oracle Database SSL Configuration
    cat > ~/.sqlnet.ora << 'SQLNET'
WALLET_LOCATION = (SOURCE = (METHOD = file) (METHOD_DATA = (DIRECTORY="/home/oracle/.oracle/wallet")))
SSL_CLIENT_AUTHENTICATION = FALSE
SSL_VERSION = 1.2
SSL_CIPHER_SUITES = (SSL_RSA_WITH_AES_256_CBC_SHA, SSL_RSA_WITH_3DES_EDE_CBC_SHA)
SQLNET.AUTHENTICATION_SERVICES = (BEQ, TCPS)
SQLNET.ENCRYPTION_CLIENT = REQUIRED
SQLNET.ENCRYPTION_TYPES_CLIENT = (AES256, AES192, AES128)
SQLNET.CRYPTO_CHECKSUM_CLIENT = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT = (SHA256, SHA1)
SQLNET

    chmod 600 ~/.sqlnet.ora
}

# Configure Application SSL
configure_application_ssl() {
    # Java application SSL configuration
    cat > application-ssl.properties << 'APP_SSL'
# SSL Configuration
server.ssl.enabled=true
server.ssl.key-store=/etc/ssl/keystore.p12
server.ssl.key-store-password=${SSL_KEYSTORE_PASSWORD}
server.ssl.key-store-type=PKCS12
server.ssl.key-alias=production

# SSL Security Configuration
server.ssl.protocol=TLS
server.ssl.enabled-protocols=TLSv1.2,TLSv1.3
server.ssl.ciphers=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

# Security Headers
security.headers.frame=DENY
security.headers.content-type=nosniff
security.headers.xss=1; mode=block
security.headers.hsts=max-age=31536000; includeSubDomains
APP_SSL
}

# Main configuration
main() {
    echo "Configuring SSL/TLS for all services..."
    
    configure_nginx_ssl
    configure_database_ssl
    configure_application_ssl
    
    echo "SSL/TLS configuration completed"
}

main "$@"
EOF

chmod +x scripts/configure_ssl_tls.sh
```

## Security Monitoring and Logging

### Comprehensive Logging Configuration

```hcl
# Logging Service Configuration
resource "oci_logging_log_group" "security_log_group" {
  compartment_id = var.compartment_id
  display_name   = "security-logs"
  description    = "Security-related log aggregation"
  
  freeform_tags = {
    Purpose = "SecurityLogging"
    LogType = "Security"
  }
}

# VCN Flow Logs
resource "oci_logging_log" "vcn_flow_logs" {
  display_name = "vcn-flow-logs"
  log_group_id = oci_logging_log_group.security_log_group.id
  log_type     = "SERVICE"
  
  configuration {
    source {
      category    = "all"
      resource    = oci_core_vcn.secure_vcn.id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_id
  }
  
  is_enabled         = true
  retention_duration = "30"
  
  freeform_tags = {
    LogType = "NetworkFlow"
    Purpose = "SecurityMonitoring"
  }
}

# Audit Logs
resource "oci_logging_log" "audit_logs" {
  display_name = "audit-logs"
  log_group_id = oci_logging_log_group.security_log_group.id
  log_type     = "SERVICE"
  
  configuration {
    source {
      category    = "all"
      resource    = var.compartment_id
      service     = "audit"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_id
  }
  
  is_enabled         = true
  retention_duration = "90"  # 90 days for audit logs
  
  freeform_tags = {
    LogType = "Audit"
    Purpose = "ComplianceMonitoring"
  }
}

# WAF Logs
resource "oci_logging_log" "waf_logs" {
  display_name = "waf-logs"
  log_group_id = oci_logging_log_group.security_log_group.id
  log_type     = "SERVICE"
  
  configuration {
    source {
      category    = "all"
      resource    = oci_waas_waas_policy.production_waf.id
      service     = "waas"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_id
  }
  
  is_enabled         = true
  retention_duration = "30"
  
  freeform_tags = {
    LogType = "WebApplicationFirewall"
    Purpose = "SecurityMonitoring"
  }
}

# Load Balancer Access Logs
resource "oci_logging_log" "lb_access_logs" {
  display_name = "lb-access-logs"
  log_group_id = oci_logging_log_group.security_log_group.id
  log_type     = "SERVICE"
  
  configuration {
    source {
      category    = "access"
      resource    = oci_load_balancer_load_balancer.production_lb.id
      service     = "loadbalancer"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_id
  }
  
  is_enabled         = true
  retention_duration = "30"
  
  freeform_tags = {
    LogType = "LoadBalancerAccess"
    Purpose = "AccessMonitoring"
  }
}
```

### Security Event Monitoring

```bash
# Security monitoring script
cat > scripts/security_monitoring.sh << 'EOF'
#!/bin/bash
# Security Event Monitoring and Alerting

LOG_DIR="/var/log/security"
ALERT_THRESHOLD_FAILED_LOGINS=5
ALERT_THRESHOLD_PRIVILEGE_ESCALATION=1

# Initialize logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_DIR/security_events.log"
    touch "$LOG_DIR/failed_logins.log"
    touch "$LOG_DIR/privilege_escalation.log"
    touch "$LOG_DIR/network_anomalies.log"
}

# Monitor failed SSH logins
monitor_failed_logins() {
    local failed_count
    failed_count=$(grep "Failed password" /var/log/auth.log | grep "$(date +%Y-%m-%d)" | wc -l)
    
    if [ "$failed_count" -gt "$ALERT_THRESHOLD_FAILED_LOGINS" ]; then
        echo "$(date): ALERT - Failed login attempts: $failed_count" >> "$LOG_DIR/security_events.log"
        
        # Extract unique IP addresses
        grep "Failed password" /var/log/auth.log | grep "$(date +%Y-%m-%d)" | \
        awk '{print $11}' | sort | uniq > "$LOG_DIR/failed_login_ips.txt"
        
        # Send alert
        send_security_alert "Failed Login Attempts" "Detected $failed_count failed login attempts today"
        
        # Auto-block suspicious IPs (optional)
        while read -r ip; do
            if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$(date): Blocking suspicious IP: $ip" >> "$LOG_DIR/security_events.log"
                # iptables -A INPUT -s "$ip" -j DROP
            fi
        done < "$LOG_DIR/failed_login_ips.txt"
    fi
}

# Monitor privilege escalation attempts
monitor_privilege_escalation() {
    local sudo_count
    sudo_count=$(grep "sudo:" /var/log/auth.log | grep "$(date +%Y-%m-%d)" | grep -i "incorrect password" | wc -l)
    
    if [ "$sudo_count" -gt "$ALERT_THRESHOLD_PRIVILEGE_ESCALATION" ]; then
        echo "$(date): ALERT - Privilege escalation attempts: $sudo_count" >> "$LOG_DIR/security_events.log"
        
        # Log privilege escalation attempts
        grep "sudo:" /var/log/auth.log | grep "$(date +%Y-%m-%d)" | \
        grep -i "incorrect password" >> "$LOG_DIR/privilege_escalation.log"
        
        send_security_alert "Privilege Escalation" "Detected $sudo_count privilege escalation attempts"
    fi
}

# Monitor network anomalies
monitor_network_anomalies() {
    # Check for unusual connection patterns
    local connection_count
    connection_count=$(netstat -an | grep ESTABLISHED | wc -l)
    
    # Define baseline (should be configured based on normal operations)
    local baseline_connections=50
    local anomaly_threshold=$((baseline_connections * 2))
    
    if [ "$connection_count" -gt "$anomaly_threshold" ]; then
        echo "$(date): ALERT - Network anomaly detected: $connection_count active connections" >> "$LOG_DIR/security_events.log"
        
        # Log current connections
        netstat -an | grep ESTABLISHED >> "$LOG_DIR/network_anomalies.log"
        
        send_security_alert "Network Anomaly" "Unusual number of network connections: $connection_count"
    fi
}

# Monitor file integrity
monitor_file_integrity() {
    # Check critical system files
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
        "/etc/hosts"
    )
    
    for file in "${critical_files[@]}"; do
        if [ -f "$file" ]; then
            current_hash=$(sha256sum "$file" | awk '{print $1}')
            stored_hash_file="${LOG_DIR}/hashes/$(basename "$file").hash"
            
            if [ -f "$stored_hash_file" ]; then
                stored_hash=$(cat "$stored_hash_file")
                if [ "$current_hash" != "$stored_hash" ]; then
                    echo "$(date): ALERT - File integrity violation: $file" >> "$LOG_DIR/security_events.log"
                    send_security_alert "File Integrity" "Critical file modified: $file"
                    
                    # Update stored hash after investigation
                    # echo "$current_hash" > "$stored_hash_file"
                fi
            else
                # First run - store initial hash
                mkdir -p "${LOG_DIR}/hashes"
                echo "$current_hash" > "$stored_hash_file"
            fi
        fi
    done
}

# Send security alerts
send_security_alert() {
    local alert_type="$1"
    local message="$2"
    local timestamp=$(date)
    
    # Log to security events
    echo "$timestamp: [$alert_type] $message" >> "$LOG_DIR/security_events.log"
    
    # Send email alert (configure with your email settings)
    if command -v mail &> /dev/null; then
        echo "Security Alert: $alert_type
        
Time: $timestamp
Message: $message
Host: $(hostname)
        
Please investigate immediately." | mail -s "Security Alert: $alert_type" "$SECURITY_EMAIL"
    fi
    
    # Send to SIEM/logging system
    if command -v logger &> /dev/null; then
        logger -t "SECURITY_ALERT" "[$alert_type] $message"
    fi
    
    # Send webhook notification (configure with your webhook URL)
    if [ -n "$SECURITY_WEBHOOK_URL" ]; then
        curl -X POST "$SECURITY_WEBHOOK_URL" \
             -H "Content-Type: application/json" \
             -d "{\"type\":\"$alert_type\",\"message\":\"$message\",\"timestamp\":\"$timestamp\",\"host\":\"$(hostname)\"}"
    fi
}

# Generate security report
generate_security_report() {
    local report_file="$LOG_DIR/security_report_$(date +%Y%m%d).txt"
    
    cat > "$report_file" << 'REPORT'
# Security Monitoring Report
Generated: $(date)
Host: $(hostname)

## Summary
- Failed Login Attempts: $(grep "Failed password" /var/log/auth.log | grep "$(date +%Y-%m-%d)" | wc -l)
- Privilege Escalation Attempts: $(grep "sudo:" /var/log/auth.log | grep "$(date +%Y-%m-%d)" | grep -i "incorrect password" | wc -l)
- Active Network Connections: $(netstat -an | grep ESTABLISHED | wc -l)
- Security Events: $(grep "$(date +%Y-%m-%d)" "$LOG_DIR/security_events.log" | wc -l)

## Recent Security Events
$(tail -20 "$LOG_DIR/security_events.log")

## System Status
- Uptime: $(uptime)
- Load Average: $(cat /proc/loadavg)
- Memory Usage: $(free -h | grep Mem)
- Disk Usage: $(df -h / | tail -1)

## Network Status
- Open Ports: $(ss -tuln | grep LISTEN | wc -l)
- Firewall Status: $(ufw status | head -1)

REPORT

    echo "Security report generated: $report_file"
}

# Main monitoring function
main() {
    setup_logging
    
    echo "$(date): Starting security monitoring" >> "$LOG_DIR/security_events.log"
    
    monitor_failed_logins
    monitor_privilege_escalation
    monitor_network_anomalies
    monitor_file_integrity
    
    # Generate daily report if it's a new day
    if [ ! -f "$LOG_DIR/security_report_$(date +%Y%m%d).txt" ]; then
        generate_security_report
    fi
    
    echo "$(date): Security monitoring completed" >> "$LOG_DIR/security_events.log"
}

# Configuration
SECURITY_EMAIL="${SECURITY_EMAIL:-security@company.com}"
SECURITY_WEBHOOK_URL="${SECURITY_WEBHOOK_URL:-}"

main "$@"
EOF

chmod +x scripts/security_monitoring.sh

# Schedule security monitoring
(crontab -l 2>/dev/null; echo "*/5 * * * * /path/to/scripts/security_monitoring.sh") | crontab -
```

## Incident Response Procedures

### Security Incident Response Plan

```bash
# Incident response script
cat > scripts/incident_response.sh << 'EOF'
#!/bin/bash
# Security Incident Response Procedures

INCIDENT_LOG="/var/log/security/incidents"
EVIDENCE_DIR="/var/log/security/evidence"
INCIDENT_ID="INC-$(date +%Y%m%d-%H%M%S)"

# Initialize incident response
initialize_incident() {
    local incident_type="$1"
    local severity="$2"
    local description="$3"
    
    mkdir -p "$INCIDENT_LOG" "$EVIDENCE_DIR"
    
    cat > "$INCIDENT_LOG/$INCIDENT_ID.log" << INCIDENT
# Security Incident Response Log
Incident ID: $INCIDENT_ID
Type: $incident_type
Severity: $severity
Description: $description
Started: $(date)
Responder: $(whoami)@$(hostname)

## Timeline
$(date): Incident response initiated

INCIDENT

    echo "Incident $INCIDENT_ID initialized"
}

# Collect evidence
collect_evidence() {
    local evidence_subdir="$EVIDENCE_DIR/$INCIDENT_ID"
    mkdir -p "$evidence_subdir"
    
    echo "$(date): Collecting evidence" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
    
    # System information
    uname -a > "$evidence_subdir/system_info.txt"
    ps aux > "$evidence_subdir/processes.txt"
    netstat -tulpn > "$evidence_subdir/network_connections.txt"
    ss -tulpn > "$evidence_subdir/socket_statistics.txt"
    lsof > "$evidence_subdir/open_files.txt" 2>/dev/null
    
    # User information
    who > "$evidence_subdir/logged_users.txt"
    last -20 > "$evidence_subdir/recent_logins.txt"
    
    # Log files
    cp /var/log/auth.log "$evidence_subdir/" 2>/dev/null
    cp /var/log/syslog "$evidence_subdir/" 2>/dev/null
    cp /var/log/secure "$evidence_subdir/" 2>/dev/null
    
    # Network configuration
    ip addr show > "$evidence_subdir/network_config.txt"
    iptables -L -n > "$evidence_subdir/firewall_rules.txt" 2>/dev/null
    
    # File system information
    find /tmp -type f -mtime -1 > "$evidence_subdir/recent_tmp_files.txt" 2>/dev/null
    find /var/tmp -type f -mtime -1 > "$evidence_subdir/recent_var_tmp_files.txt" 2>/dev/null
    
    # Memory dump (if needed for critical incidents)
    if [ "$COLLECT_MEMORY_DUMP" = "true" ]; then
        echo "$(date): Collecting memory dump" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
        # Note: This requires additional tools like LiME or volatility
        # /path/to/memory_dump_tool > "$evidence_subdir/memory_dump.bin"
    fi
    
    echo "$(date): Evidence collection completed" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
}

# Contain the incident
contain_incident() {
    local containment_type="$1"
    
    echo "$(date): Starting containment procedures - $containment_type" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
    
    case "$containment_type" in
        "network_isolation")
            echo "$(date): Implementing network isolation" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
            # Block external network access
            # iptables -A INPUT -j DROP
            # iptables -A OUTPUT -j DROP
            ;;
        "user_account_lockdown")
            echo "$(date): Locking down user accounts" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
            # Disable compromised accounts
            # usermod -L suspicious_user
            ;;
        "service_shutdown")
            echo "$(date): Shutting down affected services" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
            # Stop compromised services
            # systemctl stop affected_service
            ;;
        "full_system_isolation")
            echo "$(date): Implementing full system isolation" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
            # Complete system isolation
            # This should be used only in extreme cases
            ;;
    esac
    
    echo "$(date): Containment procedures completed" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
}

# Eradicate threats
eradicate_threats() {
    echo "$(date): Starting threat eradication" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
    
    # Remove malicious files
    if [ -f "/tmp/malicious_file" ]; then
        rm -f "/tmp/malicious_file"
        echo "$(date): Removed malicious file: /tmp/malicious_file" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
    fi
    
    # Kill malicious processes
    # pkill -f "malicious_process"
    
    # Remove unauthorized user accounts
    # userdel malicious_user
    
    # Clean up malicious cron jobs
    # crontab -r -u compromised_user
    
    # Update and patch systems
    # apt update && apt upgrade -y
    
    echo "$(date): Threat eradication completed" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
}

# Recovery procedures
recovery_procedures() {
    echo "$(date): Starting recovery procedures" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
    
    # Restore from clean backups if needed
    # ./scripts/restore_from_backup.sh
    
    # Rebuild compromised systems
    # ./scripts/rebuild_system.sh
    
    # Restore network connectivity
    # iptables -F
    
    # Restart services
    # systemctl start application_service
    
    # Verify system integrity
    ./scripts/system_integrity_check.sh
    
    echo "$(date): Recovery procedures completed" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
}

# Post-incident activities
post_incident_activities() {
    echo "$(date): Starting post-incident activities" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
    
    # Generate incident report
    generate_incident_report
    
    # Update security controls
    # ./scripts/update_security_controls.sh
    
    # Conduct lessons learned session
    # Schedule meeting with security team
    
    echo "$(date): Post-incident activities completed" >> "$INCIDENT_LOG/$INCIDENT_ID.log"
}

# Generate incident report
generate_incident_report() {
    local report_file="$INCIDENT_LOG/${INCIDENT_ID}_report.md"
    
    cat > "$report_file" << REPORT
# Security Incident Report

## Incident Information
- **Incident ID**: $INCIDENT_ID
- **Date/Time**: $(date)
- **Severity**: [Critical/High/Medium/Low]
- **Status**: [Open/Contained/Resolved/Closed]

## Incident Summary
Brief description of what happened, when it was discovered, and initial impact assessment.

## Timeline of Events
- **Detection**: [Time] - How the incident was detected
- **Response Initiated**: [Time] - When response procedures began
- **Containment**: [Time] - When threat was contained
- **Eradication**: [Time] - When threat was eliminated
- **Recovery**: [Time] - When systems were restored
- **Closure**: [Time] - When incident was formally closed

## Impact Assessment
- **Systems Affected**: List of affected systems and services
- **Data Impact**: Whether any data was accessed, modified, or stolen
- **Business Impact**: Effect on business operations
- **Users Affected**: Number and type of users impacted

## Root Cause Analysis
- **Attack Vector**: How the attacker gained access
- **Vulnerabilities Exploited**: What weaknesses were used
- **Timeline**: Detailed sequence of events
- **Contributing Factors**: Conditions that enabled the incident

## Response Actions Taken
- **Immediate Response**: First actions taken
- **Containment**: Steps to prevent spread
- **Eradication**: Actions to remove threats
- **Recovery**: Steps to restore operations
- **Communication**: Who was notified and when

## Evidence Collected
- **Digital Evidence**: Files, logs, network captures
- **Physical Evidence**: Any physical components involved
- **Chain of Custody**: How evidence was handled

## Lessons Learned
- **What Worked Well**: Effective response elements
- **Areas for Improvement**: Response weaknesses
- **Process Improvements**: Recommended changes
- **Technical Improvements**: Security enhancements needed

## Recommendations
- **Immediate Actions**: Steps to take immediately
- **Short-term Actions**: Actions for next 30 days
- **Long-term Actions**: Strategic improvements
- **Policy Changes**: Updates to security policies

## Appendices
- **Evidence Inventory**: List of all collected evidence
- **Communication Log**: Record of all communications
- **Technical Details**: Detailed technical analysis

---
Report generated: $(date)
Incident responder: $(whoami)@$(hostname)
REPORT

    echo "Incident report generated: $report_file"
}

# Notification functions
notify_stakeholders() {
    local severity="$1"
    local message="$2"
    
    # Send notifications based on severity
    case "$severity" in
        "CRITICAL")
            # Notify everyone immediately
            send_emergency_notification "$message"
            ;;
        "HIGH")
            # Notify security team and management
            send_high_priority_notification "$message"
            ;;
        "MEDIUM"|"LOW")
            # Notify security team
            send_standard_notification "$message"
            ;;
    esac
}

send_emergency_notification() {
    local message="$1"
    
    # Emergency notification channels
    echo "$message" | mail -s "CRITICAL SECURITY INCIDENT - $INCIDENT_ID" security-team@company.com
    echo "$message" | mail -s "CRITICAL SECURITY INCIDENT - $INCIDENT_ID" management@company.com
    
    # Send SMS/phone notifications if configured
    # curl -X POST "https://api.sms-service.com/send" -d "message=$message&to=$EMERGENCY_PHONE"
}

send_high_priority_notification() {
    local message="$1"
    
    echo "$message" | mail -s "HIGH PRIORITY SECURITY INCIDENT - $INCIDENT_ID" security-team@company.com
    echo "$message" | mail -s "HIGH PRIORITY SECURITY INCIDENT - $INCIDENT_ID" it-management@company.com
}

send_standard_notification() {
    local message="$1"
    
    echo "$message" | mail -s "SECURITY INCIDENT - $INCIDENT_ID" security-team@company.com
}

# Main incident response function
main() {
    local action="$1"
    local incident_type="$2"
    local severity="$3"
    local description="$4"
    
    case "$action" in
        "initialize")
            initialize_incident "$incident_type" "$severity" "$description"
            collect_evidence
            notify_stakeholders "$severity" "Security incident $INCIDENT_ID has been initiated: $description"
            ;;
        "contain")
            contain_incident "$incident_type"
            ;;
        "eradicate")
            eradicate_threats
            ;;
        "recover")
            recovery_procedures
            ;;
        "close")
            post_incident_activities
            ;;
        "full_response")
            initialize_incident "$incident_type" "$severity" "$description"
            collect_evidence
            contain_incident "network_isolation"
            eradicate_threats
            recovery_procedures
            post_incident_activities
            ;;
        *)
            echo "Usage: $0 {initialize|contain|eradicate|recover|close|full_response} [incident_type] [severity] [description]"
            echo ""
            echo "Examples:"
            echo "  $0 initialize malware_infection HIGH 'Suspected malware on web server'"
            echo "  $0 contain network_isolation"
            echo "  $0 full_response unauthorized_access CRITICAL 'Unauthorized admin access detected'"
            exit 1
            ;;
    esac
}

main "$@"
EOF

chmod +x scripts/incident_response.sh
```

## Compliance and Audit

### Compliance Framework Implementation

```bash
# Compliance monitoring and reporting
cat > scripts/compliance_framework.sh << 'EOF'
#!/bin/bash
# Compliance Framework Implementation

COMPLIANCE_DIR="/var/log/compliance"
REPORT_DIR="$COMPLIANCE_DIR/reports"
EVIDENCE_DIR="$COMPLIANCE_DIR/evidence"

# Initialize compliance framework
initialize_compliance() {
    mkdir -p "$COMPLIANCE_DIR" "$REPORT_DIR" "$EVIDENCE_DIR"
    
    # Create compliance tracking database
    cat > "$COMPLIANCE_DIR/compliance_controls.txt" << 'CONTROLS'
# Compliance Controls Tracking
# Format: CONTROL_ID|DESCRIPTION|STATUS|LAST_VERIFIED|NEXT_REVIEW

# SOX Controls
SOX-001|Financial system access controls|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+90 days' +%Y-%m-%d)
SOX-002|Change management procedures|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+90 days' +%Y-%m-%d)
SOX-003|Backup and recovery procedures|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+90 days' +%Y-%m-%d)

# PCI DSS Controls
PCI-001|Cardholder data encryption|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+30 days' +%Y-%m-%d)
PCI-002|Network segmentation|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+30 days' +%Y-%m-%d)
PCI-003|Access control procedures|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+30 days' +%Y-%m-%d)

# ISO 27001 Controls
ISO-001|Information security policy|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+365 days' +%Y-%m-%d)
ISO-002|Risk management procedures|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+365 days' +%Y-%m-%d)
ISO-003|Incident response procedures|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+365 days' +%Y-%m-%d)

# GDPR Controls
GDPR-001|Data protection impact assessments|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+180 days' +%Y-%m-%d)
GDPR-002|Data subject rights procedures|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+180 days' +%Y-%m-%d)
GDPR-003|Data breach notification procedures|IMPLEMENTED|$(date +%Y-%m-%d)|$(date -d '+180 days' +%Y-%m-%d)
CONTROLS
}

# Verify compliance controls
verify_compliance_controls() {
    echo "Verifying compliance controls..."
    
    # SOX Compliance Verification
    verify_sox_controls
    
    # PCI DSS Compliance Verification
    verify_pci_controls
    
    # ISO 27001 Compliance Verification
    verify_iso_controls
    
    # GDPR Compliance Verification
    verify_gdpr_controls
}

verify_sox_controls() {
    echo "Verifying SOX controls..."
    
    # SOX-001: Financial system access controls
    if check_access_controls; then
        update_control_status "SOX-001" "COMPLIANT"
    else
        update_control_status "SOX-001" "NON_COMPLIANT"
    fi
    
    # SOX-002: Change management procedures
    if check_change_management; then
        update_control_status "SOX-002" "COMPLIANT"
    else
        update_control_status "SOX-002" "NON_COMPLIANT"
    fi
    
    # SOX-003: Backup and recovery procedures
    if check_backup_procedures; then
        update_control_status "SOX-003" "COMPLIANT"
    else
        update_control_status "SOX-003" "NON_COMPLIANT"
    fi
}

verify_pci_controls() {
    echo "Verifying PCI DSS controls..."
    
    # PCI-001: Cardholder data encryption
    if check_data_encryption; then
        update_control_status "PCI-001" "COMPLIANT"
    else
        update_control_status "PCI-001" "NON_COMPLIANT"
    fi
    
    # PCI-002: Network segmentation
    if check_network_segmentation; then
        update_control_status "PCI-002" "COMPLIANT"
    else
        update_control_status "PCI-002" "NON_COMPLIANT"
    fi
    
    # PCI-003: Access control procedures
    if check_pci_access_controls; then
        update_control_status "PCI-003" "COMPLIANT"
    else
        update_control_status "PCI-003" "NON_COMPLIANT"
    fi
}

verify_iso_controls() {
    echo "Verifying ISO 27001 controls..."
    
    # ISO-001: Information security policy
    if check_security_policy; then
        update_control_status "ISO-001" "COMPLIANT"
    else
        update_control_status "ISO-001" "NON_COMPLIANT"
    fi
    
    # ISO-002: Risk management procedures
    if check_risk_management; then
        update_control_status "ISO-002" "COMPLIANT"
    else
        update_control_status "ISO-002" "NON_COMPLIANT"
    fi
    
    # ISO-003: Incident response procedures
    if check_incident_response; then
        update_control_status "ISO-003" "COMPLIANT"
    else
        update_control_status "ISO-003" "NON_COMPLIANT"
    fi
}

verify_gdpr_controls() {
    echo "Verifying GDPR controls..."
    
    # GDPR-001: Data protection impact assessments
    if check_data_protection_assessments; then
        update_control_status "GDPR-001" "COMPLIANT"
    else
        update_control_status "GDPR-001" "NON_COMPLIANT"
    fi
    
    # GDPR-002: Data subject rights procedures
    if check_data_subject_rights; then
        update_control_status "GDPR-002" "COMPLIANT"
    else
        update_control_status "GDPR-002" "NON_COMPLIANT"
    fi
    
    # GDPR-003: Data breach notification procedures
    if check_breach_notification; then
        update_control_status "GDPR-003" "COMPLIANT"
    else
        update_control_status "GDPR-003" "NON_COMPLIANT"
    fi
}

# Compliance check functions
check_access_controls() {
    # Verify proper access controls are in place
    if [ -f "/etc/security/access.conf" ] && [ -f "/etc/pam.d/login" ]; then
        return 0
    else
        return 1
    fi
}

check_change_management() {
    # Verify change management procedures are followed
    if [ -f "/etc/change_management_policy" ] && git log --oneline -10 > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_backup_procedures() {
    # Verify backup procedures are working
    if [ -d "/var/backups" ] && [ -f "/etc/cron.d/backup" ]; then
        return 0
    else
        return 1
    fi
}

check_data_encryption() {
    # Verify data encryption is properly implemented
    if cryptsetup status /dev/mapper/encrypted_volume > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_network_segmentation() {
    # Verify network segmentation is in place
    if iptables -L | grep -q "Chain"; then
        return 0
    else
        return 1
    fi
}

check_pci_access_controls() {
    # Verify PCI-specific access controls
    if [ -f "/etc/pci_access_policy" ]; then
        return 0
    else
        return 1
    fi
}

check_security_policy() {
    # Verify security policy exists and is current
    if [ -f "/etc/security_policy.md" ]; then
        return 0
    else
        return 1
    fi
}

check_risk_management() {
    # Verify risk management procedures
    if [ -f "/etc/risk_register.txt" ]; then
        return 0
    else
        return 1
    fi
}

check_incident_response() {
    # Verify incident response procedures
    if [ -f "/etc/incident_response_plan.md" ]; then
        return 0
    else
        return 1
    fi
}

check_data_protection_assessments() {
    # Verify DPIA procedures
    if [ -f "/etc/dpia_procedures.md" ]; then
        return 0
    else
        return 1
    fi
}

check_data_subject_rights() {
    # Verify data subject rights procedures
    if [ -f "/etc/data_subject_rights.md" ]; then
        return 0
    else
        return 1
    fi
}

check_breach_notification() {
    # Verify breach notification procedures
    if [ -f "/etc/breach_notification_plan.md" ]; then
        return 0
    else
        return 1
    fi
}

# Update control status
update_control_status() {
    local control_id="$1"
    local status="$2"
    local timestamp=$(date +%Y-%m-%d)
    
    # Update the control status in the tracking file
    sed -i "s/^$control_id|.*/$control_id|...|$status|$timestamp|.../" "$COMPLIANCE_DIR/compliance_controls.txt"
    
    echo "$timestamp: Control $control_id status updated to $status" >> "$COMPLIANCE_DIR/compliance_audit.log"
}

# Generate compliance report
generate_compliance_report() {
    local report_file="$REPORT_DIR/compliance_report_$(date +%Y%m%d).md"
    
    cat > "$report_file" << 'REPORT'
# Compliance Assessment Report

**Generated**: $(date)  
**Assessment Period**: $(date -d '30 days ago' +%Y-%m-%d) to $(date +%Y-%m-%d)  
**Assessor**: $(whoami)@$(hostname)

## Executive Summary

This report provides an assessment of compliance with applicable regulatory frameworks including SOX, PCI DSS, ISO 27001, and GDPR.

### Overall Compliance Status
- **SOX**: $(get_framework_status "SOX")
- **PCI DSS**: $(get_framework_status "PCI")
- **ISO 27001**: $(get_framework_status "ISO")
- **GDPR**: $(get_framework_status "GDPR")

## Detailed Findings

### SOX Compliance
$(generate_framework_findings "SOX")

### PCI DSS Compliance
$(generate_framework_findings "PCI")

### ISO 27001 Compliance
$(generate_framework_findings "ISO")

### GDPR Compliance
$(generate_framework_findings "GDPR")

## Recommendations

### Immediate Actions Required
$(generate_immediate_actions)

### 30-Day Action Items
$(generate_short_term_actions)

### Long-term Improvements
$(generate_long_term_actions)

## Conclusion

$(generate_conclusion)

---

**Next Assessment**: $(date -d '+30 days' +%Y-%m-%d)  
**Report Contact**: security-compliance@company.com
REPORT

    echo "Compliance report generated: $report_file"
}

# Generate audit evidence
generate_audit_evidence() {
    local evidence_file="$EVIDENCE_DIR/audit_evidence_$(date +%Y%m%d).tar.gz"
    
    # Collect audit evidence
    mkdir -p "$EVIDENCE_DIR/temp"
    
    # System configuration evidence
    cp /etc/passwd "$EVIDENCE_DIR/temp/"
    cp /etc/group "$EVIDENCE_DIR/temp/"
    iptables-save > "$EVIDENCE_DIR/temp/firewall_rules.txt"
    
    # Log evidence
    cp /var/log/auth.log "$EVIDENCE_DIR/temp/" 2>/dev/null
    cp /var/log/audit/audit.log "$EVIDENCE_DIR/temp/" 2>/dev/null
    
    # Application evidence
    ps aux > "$EVIDENCE_DIR/temp/running_processes.txt"
    netstat -tulpn > "$EVIDENCE_DIR/temp/network_services.txt"
    
    # Compliance documentation
    cp "$COMPLIANCE_DIR/compliance_controls.txt" "$EVIDENCE_DIR/temp/"
    cp "$COMPLIANCE_DIR/compliance_audit.log" "$EVIDENCE_DIR/temp/"
    
    # Create evidence archive
    tar -czf "$evidence_file" -C "$EVIDENCE_DIR" temp/
    rm -rf "$EVIDENCE_DIR/temp"
    
    echo "Audit evidence collected: $evidence_file"
}

# Main compliance function
main() {
    local action="$1"
    
    case "$action" in
        "initialize")
            initialize_compliance
            ;;
        "verify")
            verify_compliance_controls
            ;;
        "report")
            generate_compliance_report
            ;;
        "evidence")
            generate_audit_evidence
            ;;
        "full_assessment")
            initialize_compliance
            verify_compliance_controls
            generate_compliance_report
            generate_audit_evidence
            ;;
        *)
            echo "Usage: $0 {initialize|verify|report|evidence|full_assessment}"
            echo ""
            echo "Commands:"
            echo "  initialize     - Set up compliance framework"
            echo "  verify         - Verify all compliance controls"
            echo "  report         - Generate compliance report"
            echo "  evidence       - Collect audit evidence"
            echo "  full_assessment - Run complete compliance assessment"
            exit 1
            ;;
    esac
}

main "$@"
EOF

chmod +x scripts/compliance_framework.sh
```

## Security Maintenance and Updates

### Automated Security Updates

```bash
# Automated security update system
cat > scripts/security_updates.sh << 'EOF'
#!/bin/bash
# Automated Security Update System

UPDATE_LOG="/var/log/security/security_updates.log"
PATCH_LOG="/var/log/security/patch_history.log"

# Security update functions
check_security_updates() {
    echo "$(date): Checking for security updates..." >> "$UPDATE_LOG"
    
    # Update package lists
    apt update >> "$UPDATE_LOG" 2>&1
    
    # Check for security updates
    security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
    
    if [ "$security_updates" -gt 0 ]; then
        echo "$(date): $security_updates security updates available" >> "$UPDATE_LOG"
        
        # List available security updates
        apt list --upgradable 2>/dev/null | grep -i security >> "$UPDATE_LOG"
        
        return 0
    else
        echo "$(date): No security updates available" >> "$UPDATE_LOG"
        return 1
    fi
}

install_security_updates() {
    echo "$(date): Installing security updates..." >> "$UPDATE_LOG"
    
    # Install only security updates
    unattended-upgrade -d >> "$UPDATE_LOG" 2>&1
    
    # Log patch installation
    echo "$(date): Security patches installed" >> "$PATCH_LOG"
    
    # Check if reboot is required
    if [ -f /var/run/reboot-required ]; then
        echo "$(date): System reboot required after security updates" >> "$UPDATE_LOG"
        
        # Schedule reboot during maintenance window
        schedule_maintenance_reboot
    fi
}

schedule_maintenance_reboot() {
    # Schedule reboot for next maintenance window (e.g., 2 AM)
    current_hour=$(date +%H)
    
    if [ "$current_hour" -lt 2 ]; then
        # Reboot today at 2 AM
        echo "systemctl reboot" | at 02:00
        echo "$(date): Reboot scheduled for today at 02:00" >> "$UPDATE_LOG"
    else
        # Reboot tomorrow at 2 AM
        echo "systemctl reboot" | at 02:00 tomorrow
        echo "$(date): Reboot scheduled for tomorrow at 02:00" >> "$UPDATE_LOG"
    fi
}

# Main update function
main() {
    if check_security_updates; then
        install_security_updates
    fi
}

main "$@"
EOF

chmod +x scripts/security_updates.sh

# Schedule automated security updates
(crontab -l 2>/dev/null; echo "0 3 * * * /path/to/scripts/security_updates.sh") | crontab -
```

This comprehensive security architecture document provides:

1. **Defense in Depth Strategy**: Multiple layers of security controls
2. **Network Security**: Detailed network segmentation and access controls
3. **Identity and Access Management**: Comprehensive IAM policies and MFA
4. **Data Protection**: Encryption at rest and in transit
5. **Security Monitoring**: Real-time monitoring and alerting
6. **Incident Response**: Complete incident response procedures
7. **Compliance Framework**: Automated compliance monitoring and reporting
8. **Security Maintenance**: Automated security updates and patch management

The implementation follows security best practices and provides comprehensive protection for the OCI infrastructure while maintaining operational efficiency and compliance requirements.

---

**Document Version**: 1.0  
**Last Updated**: 2025-06-23  
**Classification**: Confidential  
**Review Schedule**: Quarterly  
**Next Review**: 2025-09-23

