#!/bin/bash

# OCI Infrastructure Security Updates and Maintenance Script
# This script performs regular security updates and maintenance tasks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/oci-security-maintenance.log"
BACKUP_DIR="/backup/security-maintenance"
DATE=$(date +"%Y%m%d_%H%M%S")

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Create necessary directories
mkdir -p "$(dirname "$LOG_FILE")" || true
mkdir -p "$BACKUP_DIR" || true

log "Starting security maintenance cycle - $DATE"

# Function to update system packages
update_system_packages() {
    log "Updating system packages..."
    
    # Check if running on Oracle Linux
    if command -v yum &> /dev/null; then
        log "Detected YUM package manager (Oracle Linux/RHEL)"
        sudo yum update -y --security || error_exit "Failed to update packages with yum"
        sudo yum autoremove -y || log "Warning: autoremove failed"
    elif command -v apt &> /dev/null; then
        log "Detected APT package manager (Ubuntu/Debian)"
        sudo apt update -y || error_exit "Failed to update package lists"
        sudo apt upgrade -y || error_exit "Failed to upgrade packages"
        sudo apt autoremove -y || log "Warning: autoremove failed"
        sudo apt autoclean || log "Warning: autoclean failed"
    else
        log "Warning: No supported package manager found"
    fi
}

# Function to update OCI CLI
update_oci_cli() {
    log "Updating OCI CLI..."
    
    if command -v oci &> /dev/null; then
        # Get current version
        CURRENT_VERSION=$(oci --version 2>/dev/null | head -n1 || echo "unknown")
        log "Current OCI CLI version: $CURRENT_VERSION"
        
        # Update OCI CLI
        bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults || log "Warning: OCI CLI update failed"
        
        # Verify new version
        NEW_VERSION=$(oci --version 2>/dev/null | head -n1 || echo "unknown")
        log "Updated OCI CLI version: $NEW_VERSION"
    else
        log "OCI CLI not found, skipping update"
    fi
}

# Function to update Terraform
update_terraform() {
    log "Checking Terraform version..."
    
    if command -v terraform &> /dev/null; then
        CURRENT_TF_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
        log "Current Terraform version: $CURRENT_TF_VERSION"
        
        # Get latest version from HashiCorp
        LATEST_TF_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r '.tag_name' | sed 's/v//' || echo "unknown")
        log "Latest Terraform version: $LATEST_TF_VERSION"
        
        if [ "$CURRENT_TF_VERSION" != "$LATEST_TF_VERSION" ] && [ "$LATEST_TF_VERSION" != "unknown" ]; then
            log "Terraform update available, consider manual upgrade"
            # Note: Terraform updates should be carefully managed in production
        fi
    else
        log "Terraform not found"
    fi
}

# Function to scan for security vulnerabilities
security_scan() {
    log "Running security vulnerability scan..."
    
    # Check for commonly vulnerable files and configurations
    FINDINGS=0
    
    # Check for world-writable files
    log "Checking for world-writable files..."
    if find /home /opt /var -type f -perm -002 2>/dev/null | head -10; then
        ((FINDINGS++))
        log "Warning: Found world-writable files"
    fi
    
    # Check for SUID files
    log "Checking for SUID files..."
    find /usr -type f -perm -4000 2>/dev/null > "$BACKUP_DIR/suid_files_$DATE.txt"
    log "SUID files inventory saved to $BACKUP_DIR/suid_files_$DATE.txt"
    
    # Check SSH configuration
    if [ -f /etc/ssh/sshd_config ]; then
        log "Checking SSH configuration..."
        
        # Check for insecure SSH settings
        if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
            ((FINDINGS++))
            log "WARNING: Root login is enabled in SSH"
        fi
        
        if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
            log "INFO: Password authentication is enabled"
        fi
    fi
    
    # Check for failed login attempts
    if [ -f /var/log/auth.log ]; then
        FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log | wc -l)
        log "Failed login attempts in auth.log: $FAILED_LOGINS"
    elif [ -f /var/log/secure ]; then
        FAILED_LOGINS=$(grep "Failed password" /var/log/secure | wc -l)
        log "Failed login attempts in secure log: $FAILED_LOGINS"
    fi
    
    log "Security scan completed. Issues found: $FINDINGS"
}

# Function to check SSL certificates
check_ssl_certificates() {
    log "Checking SSL certificate expiration..."
    
    # Check common certificate locations
    CERT_LOCATIONS=(
        "/etc/ssl/certs"
        "/etc/pki/tls/certs"
        "/opt/ssl"
    )
    
    for cert_dir in "${CERT_LOCATIONS[@]}"; do
        if [ -d "$cert_dir" ]; then
            log "Checking certificates in $cert_dir"
            find "$cert_dir" -name "*.crt" -o -name "*.pem" 2>/dev/null | while read -r cert_file; do
                if openssl x509 -in "$cert_file" -noout -checkend 2592000 2>/dev/null; then
                    log "Certificate OK: $cert_file"
                else
                    log "WARNING: Certificate expiring soon or invalid: $cert_file"
                fi
            done
        fi
    done
}

# Function to backup security configurations
backup_security_configs() {
    log "Backing up security configurations..."
    
    BACKUP_SECURITY_DIR="$BACKUP_DIR/security_configs_$DATE"
    mkdir -p "$BACKUP_SECURITY_DIR"
    
    # Backup important security files
    SECURITY_FILES=(
        "/etc/ssh/sshd_config"
        "/etc/sudoers"
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/hosts.deny"
        "/etc/hosts.allow"
        "/etc/security"
    )
    
    for file in "${SECURITY_FILES[@]}"; do
        if [ -f "$file" ] || [ -d "$file" ]; then
            cp -r "$file" "$BACKUP_SECURITY_DIR/" 2>/dev/null || log "Warning: Failed to backup $file"
        fi
    done
    
    log "Security configurations backed up to $BACKUP_SECURITY_DIR"
}

# Function to generate security report
generate_security_report() {
    log "Generating security report..."
    
    REPORT_FILE="$BACKUP_DIR/security_report_$DATE.txt"
    
    cat > "$REPORT_FILE" << EOF
OCI Infrastructure Security Report
Generated: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)

=== System Updates ===
Last package update: $(stat -c %y /var/log/yum.log 2>/dev/null || stat -c %y /var/log/apt/history.log 2>/dev/null || echo "Unknown")

=== Active Services ===
$(systemctl list-units --type=service --state=active | head -20)

=== Network Connections ===
$(netstat -tuln | head -20)

=== Disk Usage ===
$(df -h)

=== Memory Usage ===
$(free -h)

=== Recent Logins ===
$(last | head -10)

=== Running Processes ===
$(ps aux | head -20)

EOF

    log "Security report generated: $REPORT_FILE"
}

# Function to restart services if needed
restart_services() {
    log "Checking if services need restart..."
    
    # Check if system reboot is required
    if [ -f /var/run/reboot-required ]; then
        log "WARNING: System reboot required"
    fi
    
    # Check for services that need restart (Ubuntu/Debian)
    if command -v needrestart &> /dev/null; then
        log "Running needrestart check..."
        sudo needrestart -b || log "Warning: needrestart failed"
    fi
}

# Function to clean up old files
cleanup_old_files() {
    log "Cleaning up old files..."
    
    # Clean old log files (older than 30 days)
    find /var/log -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
    
    # Clean old backup files (older than 90 days)
    find "$BACKUP_DIR" -type f -mtime +90 -delete 2>/dev/null || true
    
    # Clean temporary files
    find /tmp -type f -mtime +7 -delete 2>/dev/null || true
    
    log "Cleanup completed"
}

# Main execution
main() {
    log "=== Starting Security Maintenance ==="
    
    # Check if running as root for system updates
    if [ "$EUID" -ne 0 ]; then
        log "Warning: Not running as root. Some operations may fail."
    fi
    
    # Perform maintenance tasks
    update_system_packages
    update_oci_cli
    update_terraform
    security_scan
    check_ssl_certificates
    backup_security_configs
    generate_security_report
    restart_services
    cleanup_old_files
    
    log "=== Security Maintenance Completed ==="
    log "Maintenance log: $LOG_FILE"
    log "Backups location: $BACKUP_DIR"
}

# Execute main function
main "$@"

