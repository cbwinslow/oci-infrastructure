#!/bin/bash

# OCI Infrastructure Backup Procedures Script
# This script performs comprehensive backup operations

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/oci-backup-procedures.log"
BACKUP_ROOT="/backup"
OCI_BACKUP_BUCKET="oci-infrastructure-backups"
DATE=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=30

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
mkdir -p "$BACKUP_ROOT" || true

log "Starting backup procedures - $DATE"

# Function to check prerequisites
check_prerequisites() {
    log "Checking backup prerequisites..."
    
    # Check available disk space
    AVAILABLE_SPACE=$(df "$BACKUP_ROOT" | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=5242880  # 5GB in KB
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        error_exit "Insufficient disk space for backup. Available: ${AVAILABLE_SPACE}KB, Required: ${REQUIRED_SPACE}KB"
    fi
    
    # Check if OCI CLI is available and configured
    if command -v oci &> /dev/null; then
        if oci os ns get &> /dev/null; then
            log "OCI CLI is configured and accessible"
        else
            log "Warning: OCI CLI not properly configured for object storage"
        fi
    else
        log "Warning: OCI CLI not available for cloud backups"
    fi
    
    # Check backup tools
    REQUIRED_TOOLS=("tar" "gzip" "rsync")
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error_exit "Required tool not found: $tool"
        fi
    done
    
    log "Prerequisites check completed"
}

# Function to backup system configurations
backup_system_configs() {
    log "Backing up system configurations..."
    
    CONFIG_BACKUP_DIR="$BACKUP_ROOT/configs_$DATE"
    mkdir -p "$CONFIG_BACKUP_DIR"
    
    # System configuration files
    CONFIG_PATHS=(
        "/etc"
        "/boot/grub"
        "/var/spool/cron"
        "/root/.ssh"
        "/home/*/.ssh"
    )
    
    for path in "${CONFIG_PATHS[@]}"; do
        if [ -d "$path" ] || [ -f "$path" ]; then
            log "Backing up $path"
            rsync -av "$path" "$CONFIG_BACKUP_DIR/" 2>/dev/null || log "Warning: Failed to backup $path"
        fi
    done
    
    # Create system information snapshot
    cat > "$CONFIG_BACKUP_DIR/system_info.txt" << EOF
System Information Snapshot
Generated: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
OS Release: $(cat /etc/os-release 2>/dev/null || echo "Unknown")
Uptime: $(uptime)
Mount Points: 
$(mount)
Network Interfaces:
$(ip addr show)
Installed Packages:
$(rpm -qa 2>/dev/null || dpkg -l 2>/dev/null || echo "Package list unavailable")
EOF

    # Create compressed archive
    cd "$BACKUP_ROOT"
    tar -czf "system_configs_$DATE.tar.gz" "configs_$DATE/" 2>/dev/null || log "Warning: Failed to create config archive"
    
    # Remove uncompressed directory to save space
    rm -rf "$CONFIG_BACKUP_DIR"
    
    log "System configuration backup completed"
}

# Function to backup application data
backup_application_data() {
    log "Backing up application data..."
    
    APP_BACKUP_DIR="$BACKUP_ROOT/applications_$DATE"
    mkdir -p "$APP_BACKUP_DIR"
    
    # Common application directories
    APP_PATHS=(
        "/opt"
        "/var/www"
        "/srv"
        "/usr/local"
    )
    
    for path in "${APP_PATHS[@]}"; do
        if [ -d "$path" ] && [ "$(ls -A "$path" 2>/dev/null)" ]; then
            log "Backing up $path"
            rsync -av --exclude='*.log' --exclude='cache/*' "$path" "$APP_BACKUP_DIR/" 2>/dev/null || log "Warning: Failed to backup $path"
        fi
    done
    
    # Create compressed archive
    cd "$BACKUP_ROOT"
    tar -czf "applications_$DATE.tar.gz" "applications_$DATE/" 2>/dev/null || log "Warning: Failed to create application archive"
    
    # Remove uncompressed directory
    rm -rf "$APP_BACKUP_DIR"
    
    log "Application data backup completed"
}

# Function to backup databases
backup_databases() {
    log "Backing up databases..."
    
    DB_BACKUP_DIR="$BACKUP_ROOT/databases_$DATE"
    mkdir -p "$DB_BACKUP_DIR"
    
    # PostgreSQL backup
    if systemctl is-active postgresql &> /dev/null; then
        log "Backing up PostgreSQL databases..."
        
        # Get list of databases
        DBS=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null | grep -v "^$" || echo "")
        
        for db in $DBS; do
            if [ -n "$db" ] && [ "$db" != "postgres" ]; then
                log "Backing up PostgreSQL database: $db"
                sudo -u postgres pg_dump "$db" | gzip > "$DB_BACKUP_DIR/postgresql_${db}_$DATE.sql.gz" 2>/dev/null || log "Warning: Failed to backup PostgreSQL database $db"
            fi
        done
        
        # Backup globals
        sudo -u postgres pg_dumpall --globals-only | gzip > "$DB_BACKUP_DIR/postgresql_globals_$DATE.sql.gz" 2>/dev/null || log "Warning: Failed to backup PostgreSQL globals"
    fi
    
    # MySQL/MariaDB backup
    if systemctl is-active mysql &> /dev/null || systemctl is-active mariadb &> /dev/null; then
        log "Backing up MySQL/MariaDB databases..."
        
        # Get list of databases
        DBS=$(mysql -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "Database|information_schema|performance_schema|mysql|sys" || echo "")
        
        for db in $DBS; do
            if [ -n "$db" ]; then
                log "Backing up MySQL database: $db"
                mysqldump "$db" | gzip > "$DB_BACKUP_DIR/mysql_${db}_$DATE.sql.gz" 2>/dev/null || log "Warning: Failed to backup MySQL database $db"
            fi
        done
    fi
    
    # Oracle database backup (if applicable)
    if systemctl is-active oracle-database &> /dev/null; then
        log "Oracle database detected, creating backup script..."
        cat > "$DB_BACKUP_DIR/oracle_backup_$DATE.sh" << 'EOF'
#!/bin/bash
# Oracle database backup script
# This script should be customized based on Oracle installation
export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

# Example RMAN backup
# rman target / << RMAN_EOF
# BACKUP DATABASE;
# BACKUP ARCHIVELOG ALL;
# RMAN_EOF
EOF
        chmod +x "$DB_BACKUP_DIR/oracle_backup_$DATE.sh"
    fi
    
    log "Database backup completed"
}

# Function to backup logs
backup_logs() {
    log "Backing up system and application logs..."
    
    LOG_BACKUP_DIR="$BACKUP_ROOT/logs_$DATE"
    mkdir -p "$LOG_BACKUP_DIR"
    
    # System logs
    LOG_PATHS=(
        "/var/log"
        "/var/log/audit"
        "/var/log/secure"
        "/var/log/messages"
        "/var/log/httpd"
        "/var/log/nginx"
        "/var/log/mysql"
        "/var/log/postgresql"
    )
    
    for path in "${LOG_PATHS[@]}"; do
        if [ -d "$path" ] || [ -f "$path" ]; then
            log "Backing up logs from $path"
            # Only backup logs modified in the last 7 days to save space
            find "$path" -type f -name "*.log" -mtime -7 -exec cp {} "$LOG_BACKUP_DIR/" \; 2>/dev/null || true
        fi
    done
    
    # Create compressed archive
    cd "$BACKUP_ROOT"
    tar -czf "logs_$DATE.tar.gz" "logs_$DATE/" 2>/dev/null || log "Warning: Failed to create log archive"
    
    # Remove uncompressed directory
    rm -rf "$LOG_BACKUP_DIR"
    
    log "Log backup completed"
}

# Function to backup user data
backup_user_data() {
    log "Backing up user data..."
    
    USER_BACKUP_DIR="$BACKUP_ROOT/users_$DATE"
    mkdir -p "$USER_BACKUP_DIR"
    
    # Backup home directories (excluding large cache directories)
    if [ -d "/home" ]; then
        rsync -av --exclude='.cache' --exclude='.local/share/Trash' --exclude='*.tmp' /home/ "$USER_BACKUP_DIR/home/" 2>/dev/null || log "Warning: Failed to backup /home"
    fi
    
    # Backup root user data
    if [ -d "/root" ]; then
        rsync -av --exclude='.cache' /root/ "$USER_BACKUP_DIR/root/" 2>/dev/null || log "Warning: Failed to backup /root"
    fi
    
    # Create compressed archive
    cd "$BACKUP_ROOT"
    tar -czf "users_$DATE.tar.gz" "users_$DATE/" 2>/dev/null || log "Warning: Failed to create user data archive"
    
    # Remove uncompressed directory
    rm -rf "$USER_BACKUP_DIR"
    
    log "User data backup completed"
}

# Function to backup to OCI Object Storage
backup_to_oci() {
    log "Uploading backups to OCI Object Storage..."
    
    if ! command -v oci &> /dev/null; then
        log "OCI CLI not available, skipping cloud backup"
        return
    fi
    
    # Check if bucket exists, create if not
    if ! oci os bucket get --bucket-name "$OCI_BACKUP_BUCKET" &> /dev/null; then
        log "Creating OCI backup bucket: $OCI_BACKUP_BUCKET"
        oci os bucket create --name "$OCI_BACKUP_BUCKET" --compartment-id "$(oci iam compartment list --query 'data[0].id' --raw-output)" || log "Warning: Failed to create backup bucket"
    fi
    
    # Upload backup files
    cd "$BACKUP_ROOT"
    for backup_file in *_$DATE.tar.gz; do
        if [ -f "$backup_file" ]; then
            log "Uploading $backup_file to OCI Object Storage..."
            oci os object put --bucket-name "$OCI_BACKUP_BUCKET" --file "$backup_file" --name "$(hostname)/$backup_file" || log "Warning: Failed to upload $backup_file"
        fi
    done
    
    log "OCI Object Storage backup completed"
}

# Function to create backup manifest
create_backup_manifest() {
    log "Creating backup manifest..."
    
    MANIFEST_FILE="$BACKUP_ROOT/backup_manifest_$DATE.txt"
    
    cat > "$MANIFEST_FILE" << EOF
OCI Infrastructure Backup Manifest
Generated: $(date)
Hostname: $(hostname)
Backup Session: $DATE

=== Backup Files Created ===
EOF

    # List all backup files with sizes
    find "$BACKUP_ROOT" -name "*_$DATE*" -type f -exec ls -lh {} \; >> "$MANIFEST_FILE"
    
    cat >> "$MANIFEST_FILE" << EOF

=== System Information ===
Kernel: $(uname -r)
Uptime: $(uptime)
Disk Usage Before Backup:
$(df -h)

=== Backup Statistics ===
EOF

    # Calculate total backup size
    TOTAL_SIZE=$(find "$BACKUP_ROOT" -name "*_$DATE*" -type f -exec stat -c%s {} \; | awk '{sum+=$1} END {print sum}')
    TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024 / 1024))
    
    echo "Total Backup Size: ${TOTAL_SIZE_MB}MB" >> "$MANIFEST_FILE"
    echo "Backup Retention: $RETENTION_DAYS days" >> "$MANIFEST_FILE"
    
    log "Backup manifest created: $MANIFEST_FILE"
}

# Function to cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (older than $RETENTION_DAYS days)..."
    
    # Local cleanup
    find "$BACKUP_ROOT" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_ROOT" -name "*.txt" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_ROOT" -name "*.log" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # OCI Object Storage cleanup
    if command -v oci &> /dev/null; then
        log "Cleaning up old backups from OCI Object Storage..."
        
        # List objects older than retention period
        CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
        
        oci os object list --bucket-name "$OCI_BACKUP_BUCKET" --prefix "$(hostname)/" --query "data[?\"time-created\" < '$CUTOFF_DATE'].name" --raw-output 2>/dev/null | while read -r object_name; do
            if [ -n "$object_name" ]; then
                log "Deleting old backup from OCI: $object_name"
                oci os object delete --bucket-name "$OCI_BACKUP_BUCKET" --object-name "$object_name" --force 2>/dev/null || log "Warning: Failed to delete $object_name"
            fi
        done
    fi
    
    log "Cleanup completed"
}

# Function to verify backup integrity
verify_backups() {
    log "Verifying backup integrity..."
    
    cd "$BACKUP_ROOT"
    VERIFICATION_REPORT="$BACKUP_ROOT/backup_verification_$DATE.txt"
    
    cat > "$VERIFICATION_REPORT" << EOF
Backup Verification Report
Generated: $(date)

=== File Integrity Check ===
EOF

    # Verify each backup archive
    for backup_file in *_$DATE.tar.gz; do
        if [ -f "$backup_file" ]; then
            log "Verifying $backup_file"
            if tar -tzf "$backup_file" > /dev/null 2>&1; then
                echo "✓ $backup_file - VALID" >> "$VERIFICATION_REPORT"
            else
                echo "✗ $backup_file - CORRUPTED" >> "$VERIFICATION_REPORT"
                log "WARNING: Backup file $backup_file appears to be corrupted"
            fi
        fi
    done
    
    cat >> "$VERIFICATION_REPORT" << EOF

=== Backup Size Analysis ===
$(ls -lh *_$DATE*)

=== Available Disk Space After Backup ===
$(df -h "$BACKUP_ROOT")

EOF

    log "Backup verification completed: $VERIFICATION_REPORT"
}

# Function to send backup notification
send_backup_notification() {
    log "Sending backup notification..."
    
    # Create notification summary
    NOTIFICATION_FILE="$BACKUP_ROOT/backup_notification_$DATE.txt"
    
    cat > "$NOTIFICATION_FILE" << EOF
OCI Infrastructure Backup Notification
Date: $(date)
Hostname: $(hostname)

Backup Status: SUCCESS
Backup Session ID: $DATE

Files Created:
$(find "$BACKUP_ROOT" -name "*_$DATE*" -type f | wc -l) backup files

Total Size: $(find "$BACKUP_ROOT" -name "*_$DATE*" -type f -exec stat -c%s {} \; | awk '{sum+=$1} END {printf "%.2f MB", sum/1024/1024}')

Next Scheduled Backup: $(date -d "tomorrow 2:00" '+%Y-%m-%d %H:%M')

For detailed information, check: $LOG_FILE
EOF

    # If email is configured, send notification
    if command -v mail &> /dev/null && [ -n "${BACKUP_EMAIL:-}" ]; then
        mail -s "OCI Infrastructure Backup Complete - $(hostname)" "$BACKUP_EMAIL" < "$NOTIFICATION_FILE" || log "Warning: Failed to send email notification"
    fi
    
    log "Notification file created: $NOTIFICATION_FILE"
}

# Function to create recovery instructions
create_recovery_instructions() {
    log "Creating recovery instructions..."
    
    RECOVERY_FILE="$BACKUP_ROOT/recovery_instructions_$DATE.txt"
    
    cat > "$RECOVERY_FILE" << EOF
OCI Infrastructure Recovery Instructions
Backup Date: $(date)
Backup Session: $DATE

=== System Configuration Recovery ===
1. Extract system configs:
   tar -xzf system_configs_$DATE.tar.gz
   
2. Restore critical configs:
   sudo cp -r configs_$DATE/etc/* /etc/
   sudo cp -r configs_$DATE/boot/* /boot/
   
3. Restart services:
   sudo systemctl daemon-reload
   sudo systemctl restart sshd

=== Application Data Recovery ===
1. Extract application data:
   tar -xzf applications_$DATE.tar.gz
   
2. Restore applications:
   sudo cp -r applications_$DATE/opt/* /opt/
   sudo cp -r applications_$DATE/var/www/* /var/www/

=== Database Recovery ===
PostgreSQL:
   gunzip postgresql_dbname_$DATE.sql.gz
   sudo -u postgres psql dbname < postgresql_dbname_$DATE.sql

MySQL:
   gunzip mysql_dbname_$DATE.sql.gz
   mysql dbname < mysql_dbname_$DATE.sql

=== User Data Recovery ===
1. Extract user data:
   tar -xzf users_$DATE.tar.gz
   
2. Restore user homes:
   sudo cp -r users_$DATE/home/* /home/
   sudo cp -r users_$DATE/root/* /root/

=== Log Recovery ===
1. Extract logs:
   tar -xzf logs_$DATE.tar.gz
   
2. Review historical logs as needed

=== OCI Object Storage Recovery ===
Download backups from OCI:
   oci os object get --bucket-name $OCI_BACKUP_BUCKET --name $(hostname)/backup_file_name --file backup_file_name

=== Important Notes ===
- Always test recovery procedures in a non-production environment first
- Verify file permissions after restoration
- Check service configurations after recovery
- Review security settings post-recovery

EOF

    log "Recovery instructions created: $RECOVERY_FILE"
}

# Main execution
main() {
    log "=== Starting Comprehensive Backup Procedures ==="
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log "Warning: Not running as root. Some backups may fail."
    fi
    
    # Execute backup procedures
    check_prerequisites
    backup_system_configs
    backup_application_data
    backup_databases
    backup_logs
    backup_user_data
    create_backup_manifest
    verify_backups
    backup_to_oci
    cleanup_old_backups
    create_recovery_instructions
    send_backup_notification
    
    log "=== Backup Procedures Completed Successfully ==="
    log "Backup location: $BACKUP_ROOT"
    log "Log file: $LOG_FILE"
    log "Session ID: $DATE"
}

# Execute main function
main "$@"

