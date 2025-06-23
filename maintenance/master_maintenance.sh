#!/bin/bash

# OCI Infrastructure Master Maintenance Script
# This script orchestrates all maintenance procedures

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/oci-master-maintenance.log"
DATE=$(date +"%Y%m%d_%H%M%S")

# Maintenance scripts
SECURITY_SCRIPT="$SCRIPT_DIR/security_updates.sh"
PERFORMANCE_SCRIPT="$SCRIPT_DIR/performance_optimization.sh"
CONFIG_SCRIPT="$SCRIPT_DIR/configuration_management.sh"
BACKUP_SCRIPT="$SCRIPT_DIR/backup_procedures.sh"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Function to check if script exists and is executable
check_script() {
    local script_path="$1"
    local script_name="$2"
    
    if [ ! -f "$script_path" ]; then
        log "WARNING: $script_name script not found at $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        log "Making $script_name script executable..."
        chmod +x "$script_path" || log "Warning: Failed to make $script_path executable"
    fi
    
    return 0
}

# Function to run maintenance script with error handling
run_maintenance_script() {
    local script_path="$1"
    local script_name="$2"
    local args="${3:-}"
    
    log "=== Starting $script_name ==="
    
    if check_script "$script_path" "$script_name"; then
        log "Executing: $script_path $args"
        
        # Run script and capture output
        if bash "$script_path" $args 2>&1 | tee -a "$LOG_FILE"; then
            log "$script_name completed successfully"
            return 0
        else
            log "ERROR: $script_name failed"
            return 1
        fi
    else
        log "Skipping $script_name due to missing script"
        return 1
    fi
}

# Function to generate maintenance summary report
generate_maintenance_report() {
    log "Generating maintenance summary report..."
    
    local report_file="/var/reports/maintenance_summary_$DATE.txt"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
OCI Infrastructure Maintenance Summary Report
Generated: $(date)
Hostname: $(hostname)
Maintenance Session: $DATE

=== System Status Before Maintenance ===
Uptime: $(uptime)
Load Average: $(cat /proc/loadavg)
Memory Usage: $(free -h | grep Mem)
Disk Usage: $(df -h / | tail -1)
Active Services: $(systemctl list-units --type=service --state=active | wc -l)

=== Maintenance Tasks Executed ===
EOF

    # Check which maintenance tasks were completed
    if grep -q "Security Maintenance Completed" "$LOG_FILE" 2>/dev/null; then
        echo "✓ Security Updates and Hardening" >> "$report_file"
    else
        echo "✗ Security Updates and Hardening" >> "$report_file"
    fi
    
    if grep -q "Performance Optimization Completed" "$LOG_FILE" 2>/dev/null; then
        echo "✓ Performance Optimization" >> "$report_file"
    else
        echo "✗ Performance Optimization" >> "$report_file"
    fi
    
    if grep -q "Configuration Management Completed" "$LOG_FILE" 2>/dev/null; then
        echo "✓ Configuration Management" >> "$report_file"
    else
        echo "✗ Configuration Management" >> "$report_file"
    fi
    
    if grep -q "Backup Procedures Completed" "$LOG_FILE" 2>/dev/null; then
        echo "✓ Backup Procedures" >> "$report_file"
    else
        echo "✗ Backup Procedures" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

=== System Status After Maintenance ===
Uptime: $(uptime)
Load Average: $(cat /proc/loadavg)
Memory Usage: $(free -h | grep Mem)
Disk Usage: $(df -h / | tail -1)
Active Services: $(systemctl list-units --type=service --state=active | wc -l)

=== Maintenance Logs ===
Main Log: $LOG_FILE
Security Log: /var/log/oci-security-maintenance.log
Performance Log: /var/log/oci-performance-optimization.log
Configuration Log: /var/log/oci-configuration-management.log
Backup Log: /var/log/oci-backup-procedures.log

=== Next Scheduled Maintenance ===
$(crontab -l 2>/dev/null | grep -E "(security|performance|backup|config)" | head -5)

=== Recommendations ===
1. Review individual maintenance logs for detailed information
2. Verify system functionality after maintenance
3. Monitor system performance for the next 24 hours
4. Check backup integrity and cloud storage synchronization
5. Update maintenance schedules if needed

EOF

    log "Maintenance summary report created: $report_file"
}

# Function to setup maintenance environment
setup_maintenance_environment() {
    log "Setting up maintenance environment..."
    
    # Create necessary directories
    mkdir -p /var/log
    mkdir -p /var/reports
    mkdir -p /backup
    
    # Make all maintenance scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    
    # Check system resources before starting
    AVAILABLE_MEMORY=$(free -m | awk '/^Mem:/{print $7}')
    AVAILABLE_DISK=$(df /var | tail -1 | awk '{print $4}')
    
    if [ "$AVAILABLE_MEMORY" -lt 512 ]; then
        log "WARNING: Low memory available: ${AVAILABLE_MEMORY}MB"
    fi
    
    if [ "$AVAILABLE_DISK" -lt 1048576 ]; then  # 1GB in KB
        log "WARNING: Low disk space in /var: ${AVAILABLE_DISK}KB"
    fi
    
    log "Maintenance environment setup completed"
}

# Function to create maintenance lock file
create_maintenance_lock() {
    local lock_file="/var/run/oci-maintenance.lock"
    
    if [ -f "$lock_file" ]; then
        local lock_pid=$(cat "$lock_file" 2>/dev/null || echo "unknown")
        if kill -0 "$lock_pid" 2>/dev/null; then
            error_exit "Another maintenance process is already running (PID: $lock_pid)"
        else
            log "Removing stale lock file"
            rm -f "$lock_file"
        fi
    fi
    
    echo $$ > "$lock_file"
    log "Created maintenance lock file: $lock_file"
}

# Function to remove maintenance lock file
remove_maintenance_lock() {
    local lock_file="/var/run/oci-maintenance.lock"
    rm -f "$lock_file" 2>/dev/null || true
    log "Removed maintenance lock file"
}

# Function to send maintenance notification
send_maintenance_notification() {
    local status="$1"
    local notification_file="/tmp/maintenance_notification_$DATE.txt"
    
    cat > "$notification_file" << EOF
OCI Infrastructure Maintenance Notification
Date: $(date)
Hostname: $(hostname)
Status: $status
Session ID: $DATE

Maintenance Tasks:
- Security Updates and Hardening
- Performance Optimization  
- Configuration Management
- Backup Procedures

Summary Report: /var/reports/maintenance_summary_$DATE.txt
Detailed Logs: $LOG_FILE

System Status:
$(systemctl is-system-running 2>/dev/null || echo "System status check failed")

Next Maintenance: $(date -d "next week" '+%Y-%m-%d %H:%M')
EOF

    # Send notification if email is configured
    if command -v mail &> /dev/null && [ -n "${MAINTENANCE_EMAIL:-}" ]; then
        mail -s "OCI Maintenance $status - $(hostname)" "$MAINTENANCE_EMAIL" < "$notification_file" || log "Warning: Failed to send email notification"
    fi
    
    log "Maintenance notification created: $notification_file"
}

# Function to run full maintenance cycle
run_full_maintenance() {
    log "=== Starting Full Maintenance Cycle ==="
    
    local success_count=0
    local total_tasks=4
    
    # 1. Security Updates
    if run_maintenance_script "$SECURITY_SCRIPT" "Security Updates"; then
        ((success_count++))
    fi
    
    # 2. Performance Optimization
    if run_maintenance_script "$PERFORMANCE_SCRIPT" "Performance Optimization"; then
        ((success_count++))
    fi
    
    # 3. Configuration Management
    if run_maintenance_script "$CONFIG_SCRIPT" "Configuration Management" "apply"; then
        ((success_count++))
    fi
    
    # 4. Backup Procedures
    if run_maintenance_script "$BACKUP_SCRIPT" "Backup Procedures"; then
        ((success_count++))
    fi
    
    log "=== Full Maintenance Cycle Completed ==="
    log "Successfully completed $success_count out of $total_tasks maintenance tasks"
    
    if [ "$success_count" -eq "$total_tasks" ]; then
        return 0
    else
        return 1
    fi
}

# Function to run specific maintenance task
run_specific_maintenance() {
    local task="$1"
    
    case "$task" in
        "security")
            run_maintenance_script "$SECURITY_SCRIPT" "Security Updates"
            ;;
        "performance")
            run_maintenance_script "$PERFORMANCE_SCRIPT" "Performance Optimization"
            ;;
        "config")
            run_maintenance_script "$CONFIG_SCRIPT" "Configuration Management" "apply"
            ;;
        "backup")
            run_maintenance_script "$BACKUP_SCRIPT" "Backup Procedures"
            ;;
        *)
            log "Unknown maintenance task: $task"
            log "Available tasks: security, performance, config, backup"
            return 1
            ;;
    esac
}

# Function to display maintenance status
show_maintenance_status() {
    log "=== Maintenance Status ==="
    
    echo "System Information:"
    echo "  Hostname: $(hostname)"
    echo "  Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "  Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"
    echo "  Memory: $(free -h | awk '/^Mem:/{printf "%s/%s (%.1f%%)", $3, $2, $3/$2*100}')"
    echo "  Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
    echo ""
    
    echo "Recent Maintenance Logs:"
    echo "  Security: $(ls -la /var/log/oci-security-maintenance.log 2>/dev/null | awk '{print $6, $7, $8}' || echo "Not found")"
    echo "  Performance: $(ls -la /var/log/oci-performance-optimization.log 2>/dev/null | awk '{print $6, $7, $8}' || echo "Not found")"
    echo "  Configuration: $(ls -la /var/log/oci-configuration-management.log 2>/dev/null | awk '{print $6, $7, $8}' || echo "Not found")"
    echo "  Backup: $(ls -la /var/log/oci-backup-procedures.log 2>/dev/null | awk '{print $6, $7, $8}' || echo "Not found")"
    echo ""
    
    echo "Scheduled Maintenance:"
    crontab -l 2>/dev/null | grep -E "(security|performance|backup|config)" || echo "  No scheduled maintenance found"
    echo ""
    
    echo "System Services:"
    systemctl list-units --type=service --state=failed --no-pager | head -10
}

# Function to install monitoring and maintenance cron jobs
install_cron_jobs() {
    log "Installing maintenance cron jobs..."
    
    # Create cron jobs for automated maintenance
    CRON_JOBS=(
        "0 2 * * 0 $SCRIPT_DIR/master_maintenance.sh security"
        "0 3 * * 1 $SCRIPT_DIR/master_maintenance.sh performance"
        "0 1 * * 0 $SCRIPT_DIR/master_maintenance.sh backup"
        "0 4 1 * * $SCRIPT_DIR/master_maintenance.sh config"
        "0 0 1 * * $SCRIPT_DIR/master_maintenance.sh full"
    )
    
    for job in "${CRON_JOBS[@]}"; do
        if ! crontab -l 2>/dev/null | grep -qF "${job#* * * * * }"; then
            (crontab -l 2>/dev/null; echo "$job") | crontab -
            log "Added cron job: $job"
        else
            log "Cron job already exists: ${job#* * * * * }"
        fi
    done
    
    log "Cron jobs installation completed"
}

# Main function
main() {
    log "=== Starting OCI Infrastructure Master Maintenance ==="
    
    # Trap to ensure cleanup on exit
    trap 'remove_maintenance_lock' EXIT
    
    # Setup maintenance environment
    setup_maintenance_environment
    create_maintenance_lock
    
    case "${1:-full}" in
        "full")
            if run_full_maintenance; then
                generate_maintenance_report
                send_maintenance_notification "SUCCESS"
            else
                generate_maintenance_report
                send_maintenance_notification "PARTIAL SUCCESS"
            fi
            ;;
        "security"|"performance"|"config"|"backup")
            if run_specific_maintenance "$1"; then
                send_maintenance_notification "SUCCESS - $1"
            else
                send_maintenance_notification "FAILED - $1"
            fi
            ;;
        "status")
            show_maintenance_status
            ;;
        "install-cron")
            install_cron_jobs
            ;;
        "setup")
            setup_maintenance_environment
            install_cron_jobs
            log "Maintenance system setup completed"
            ;;
        *)
            echo "Usage: $0 {full|security|performance|config|backup|status|install-cron|setup}"
            echo ""
            echo "Commands:"
            echo "  full           - Run all maintenance tasks"
            echo "  security       - Run security updates only"
            echo "  performance    - Run performance optimization only"
            echo "  config         - Run configuration management only"
            echo "  backup         - Run backup procedures only"
            echo "  status         - Show maintenance status"
            echo "  install-cron   - Install automated maintenance cron jobs"
            echo "  setup          - Setup maintenance environment and cron jobs"
            exit 1
            ;;
    esac
    
    log "=== Master Maintenance Completed ==="
    log "Session ID: $DATE"
    log "Log file: $LOG_FILE"
}

# Execute main function
main "$@"

