#!/bin/bash

# OCI Infrastructure Performance Optimization Script
# This script performs performance analysis and optimization tasks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/oci-performance-optimization.log"
REPORT_DIR="/var/reports/performance"
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
mkdir -p "$REPORT_DIR" || true

log "Starting performance optimization cycle - $DATE"

# Function to analyze system performance
analyze_system_performance() {
    log "Analyzing system performance..."
    
    PERF_REPORT="$REPORT_DIR/performance_analysis_$DATE.txt"
    
    cat > "$PERF_REPORT" << EOF
Performance Analysis Report
Generated: $(date)
Hostname: $(hostname)

=== CPU Information ===
$(lscpu)

=== Memory Usage ===
$(free -h)

=== Disk Usage ===
$(df -h)

=== Disk I/O Statistics ===
$(iostat -x 1 3 2>/dev/null || echo "iostat not available")

=== Network Statistics ===
$(netstat -i)

=== Load Average ===
$(uptime)

=== Top Processes by CPU ===
$(ps aux --sort=-%cpu | head -10)

=== Top Processes by Memory ===
$(ps aux --sort=-%mem | head -10)

=== Swap Usage ===
$(swapon -s 2>/dev/null || echo "No swap configured")

EOF

    log "Performance analysis saved to $PERF_REPORT"
}

# Function to optimize system parameters
optimize_system_parameters() {
    log "Optimizing system parameters..."
    
    # Backup current sysctl settings
    cp /etc/sysctl.conf "$REPORT_DIR/sysctl_backup_$DATE.conf" 2>/dev/null || true
    
    # Network optimizations
    if ! grep -q "net.core.rmem_max" /etc/sysctl.conf 2>/dev/null; then
        log "Applying network optimizations..."
        cat >> /etc/sysctl.conf << EOF

# Network performance optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
EOF
        sysctl -p || log "Warning: Failed to apply sysctl settings"
    fi
    
    # Virtual memory optimizations
    if ! grep -q "vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
        log "Applying virtual memory optimizations..."
        cat >> /etc/sysctl.conf << EOF

# Virtual memory optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1
EOF
        sysctl -p || log "Warning: Failed to apply sysctl settings"
    fi
}

# Function to optimize disk performance
optimize_disk_performance() {
    log "Optimizing disk performance..."
    
    # Check for SSD drives and optimize
    for disk in $(lsblk -nd -o NAME | grep -E '^(sd|nvme)'); do
        if [ -f "/sys/block/$disk/queue/rotational" ]; then
            ROTATIONAL=$(cat "/sys/block/$disk/queue/rotational")
            if [ "$ROTATIONAL" = "0" ]; then
                log "Optimizing SSD: $disk"
                
                # Set scheduler for SSD
                echo "noop" > "/sys/block/$disk/queue/scheduler" 2>/dev/null || \
                echo "none" > "/sys/block/$disk/queue/scheduler" 2>/dev/null || \
                log "Warning: Could not set scheduler for $disk"
                
                # Enable discard for SSD
                echo "1" > "/sys/block/$disk/queue/discard_max_bytes" 2>/dev/null || true
            else
                log "Optimizing HDD: $disk"
                # Set scheduler for HDD
                echo "deadline" > "/sys/block/$disk/queue/scheduler" 2>/dev/null || \
                echo "mq-deadline" > "/sys/block/$disk/queue/scheduler" 2>/dev/null || \
                log "Warning: Could not set scheduler for $disk"
            fi
        fi
    done
    
    # Update fstab for SSD optimization if needed
    if grep -q "ext4" /etc/fstab && ! grep -q "noatime" /etc/fstab; then
        log "Consider adding 'noatime' option to ext4 filesystems in /etc/fstab"
    fi
}

# Function to clean up system resources
cleanup_system_resources() {
    log "Cleaning up system resources..."
    
    # Clear page cache, dentries, and inodes
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || log "Warning: Could not drop caches"
    
    # Clean package cache
    if command -v yum &> /dev/null; then
        yum clean all || log "Warning: yum clean failed"
    elif command -v apt &> /dev/null; then
        apt clean || log "Warning: apt clean failed"
    fi
    
    # Remove old kernels (keep last 2)
    if command -v package-cleanup &> /dev/null; then
        package-cleanup --oldkernels --count=2 -y || log "Warning: kernel cleanup failed"
    fi
    
    # Clean temporary files
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # Vacuum journal logs
    journalctl --vacuum-time=30d 2>/dev/null || log "Warning: journal vacuum failed"
    
    log "System cleanup completed"
}

# Function to optimize database performance (if applicable)
optimize_database_performance() {
    log "Checking for database optimization opportunities..."
    
    # Check if PostgreSQL is running
    if systemctl is-active postgresql &> /dev/null; then
        log "PostgreSQL detected, checking configuration..."
        
        # Basic PostgreSQL optimizations
        PG_VERSION=$(psql --version | awk '{print $3}' | sed 's/\..*//' 2>/dev/null || echo "unknown")
        if [ "$PG_VERSION" != "unknown" ]; then
            log "PostgreSQL version: $PG_VERSION"
            
            # Check for common performance settings
            SHARED_BUFFERS=$(sudo -u postgres psql -t -c "SHOW shared_buffers;" 2>/dev/null || echo "unknown")
            log "Current shared_buffers: $SHARED_BUFFERS"
            
            EFFECTIVE_CACHE_SIZE=$(sudo -u postgres psql -t -c "SHOW effective_cache_size;" 2>/dev/null || echo "unknown")
            log "Current effective_cache_size: $EFFECTIVE_CACHE_SIZE"
        fi
    fi
    
    # Check if MySQL/MariaDB is running
    if systemctl is-active mysql &> /dev/null || systemctl is-active mariadb &> /dev/null; then
        log "MySQL/MariaDB detected, checking configuration..."
        
        # Basic MySQL optimizations check
        INNODB_BUFFER_POOL=$(mysql -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" 2>/dev/null | tail -n 1 | awk '{print $2}' || echo "unknown")
        log "Current innodb_buffer_pool_size: $INNODB_BUFFER_POOL"
    fi
}

# Function to monitor and tune network performance
optimize_network_performance() {
    log "Optimizing network performance..."
    
    # Check network interface settings
    for interface in $(ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | tr -d ' ' | grep -v lo); do
        log "Checking interface: $interface"
        
        # Check if ethtool is available and interface supports it
        if command -v ethtool &> /dev/null; then
            # Get current settings
            SPEED=$(ethtool "$interface" 2>/dev/null | grep "Speed:" | awk '{print $2}' || echo "unknown")
            DUPLEX=$(ethtool "$interface" 2>/dev/null | grep "Duplex:" | awk '{print $2}' || echo "unknown")
            log "Interface $interface: Speed=$SPEED, Duplex=$DUPLEX"
            
            # Check for offload features
            ethtool -k "$interface" > "$REPORT_DIR/network_offload_$interface_$DATE.txt" 2>/dev/null || true
        fi
        
        # Check interface statistics
        ip -s link show "$interface" > "$REPORT_DIR/network_stats_$interface_$DATE.txt" 2>/dev/null || true
    done
    
    # Tune network buffer sizes
    NET_CORE_RMEM_DEFAULT=$(sysctl -n net.core.rmem_default 2>/dev/null || echo "unknown")
    NET_CORE_WMEM_DEFAULT=$(sysctl -n net.core.wmem_default 2>/dev/null || echo "unknown")
    log "Current network buffer sizes - rmem: $NET_CORE_RMEM_DEFAULT, wmem: $NET_CORE_WMEM_DEFAULT"
}

# Function to check and optimize file system performance
optimize_filesystem_performance() {
    log "Optimizing filesystem performance..."
    
    # Check filesystem types and mount options
    mount | grep -E "ext[234]|xfs|btrfs" > "$REPORT_DIR/filesystem_mounts_$DATE.txt" 2>/dev/null || true
    
    # Check for filesystem errors
    for fs in $(mount | grep -E "ext[234]" | awk '{print $1}'); do
        log "Checking filesystem: $fs"
        tune2fs -l "$fs" 2>/dev/null | grep -E "Filesystem state|Last checked" || true
    done
    
    # Check for fragmentation on ext filesystems
    for fs in $(mount | grep -E "ext[234]" | awk '{print $3}'); do
        if [ -d "$fs" ]; then
            log "Checking fragmentation for: $fs"
            e4defrag -c "$fs" 2>/dev/null || log "e4defrag not available for $fs"
        fi
    done
}

# Function to generate performance recommendations
generate_performance_recommendations() {
    log "Generating performance recommendations..."
    
    RECOMMENDATIONS_FILE="$REPORT_DIR/performance_recommendations_$DATE.txt"
    
    cat > "$RECOMMENDATIONS_FILE" << EOF
Performance Optimization Recommendations
Generated: $(date)

=== System Resource Analysis ===
EOF

    # Memory recommendations
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
    MEM_USAGE_PCT=$((($TOTAL_MEM - $AVAILABLE_MEM) * 100 / $TOTAL_MEM))
    
    echo "Memory Usage: ${MEM_USAGE_PCT}%" >> "$RECOMMENDATIONS_FILE"
    if [ "$MEM_USAGE_PCT" -gt 85 ]; then
        echo "RECOMMENDATION: Consider adding more memory or optimizing memory usage" >> "$RECOMMENDATIONS_FILE"
    fi
    
    # CPU load recommendations
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')
    CPU_CORES=$(nproc)
    
    echo "Load Average: $LOAD_AVG (CPU Cores: $CPU_CORES)" >> "$RECOMMENDATIONS_FILE"
    if (( $(echo "$LOAD_AVG > $CPU_CORES" | bc -l 2>/dev/null || echo "0") )); then
        echo "RECOMMENDATION: System load is high, consider optimizing processes or adding CPU resources" >> "$RECOMMENDATIONS_FILE"
    fi
    
    # Disk space recommendations
    while read -r filesystem size used avail percent mountpoint; do
        usage_pct=$(echo "$percent" | tr -d '%')
        if [ "$usage_pct" -gt 85 ]; then
            echo "RECOMMENDATION: Filesystem $mountpoint is ${usage_pct}% full, consider cleanup or expansion" >> "$RECOMMENDATIONS_FILE"
        fi
    done < <(df -h | grep -E '^/' | awk '{print $1, $2, $3, $4, $5, $6}')
    
    cat >> "$RECOMMENDATIONS_FILE" << EOF

=== Configuration Recommendations ===
1. Ensure SSD disks are using appropriate I/O schedulers (noop/none)
2. Consider enabling TCP BBR congestion control for better network performance
3. Tune swappiness based on workload characteristics
4. Implement log rotation for large log files
5. Monitor and tune database-specific parameters if applicable
6. Consider implementing monitoring alerts for resource thresholds

=== Next Steps ===
1. Review the performance analysis report
2. Implement recommended optimizations gradually
3. Monitor system behavior after changes
4. Schedule regular performance reviews

EOF

    log "Performance recommendations saved to $RECOMMENDATIONS_FILE"
}

# Function to create performance monitoring cron jobs
setup_performance_monitoring() {
    log "Setting up performance monitoring..."
    
    # Create performance monitoring script
    MONITOR_SCRIPT="/usr/local/bin/performance_monitor.sh"
    
    cat > "$MONITOR_SCRIPT" << 'EOF'
#!/bin/bash
# Performance monitoring script

DATE=$(date +"%Y%m%d_%H%M%S")
MONITOR_LOG="/var/log/performance_monitor.log"

{
    echo "=== Performance Check - $(date) ==="
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory Usage: $(free -m | awk '/^Mem:/{printf "%.1f%%", ($2-$7)/$2*100}')"
    echo "Disk Usage:"
    df -h | grep -E '^/' | awk '{print $6 ": " $5}'
    echo "Top 5 CPU processes:"
    ps aux --sort=-%cpu | head -6 | tail -5
    echo "----------------------------------------"
} >> "$MONITOR_LOG"
EOF

    chmod +x "$MONITOR_SCRIPT"
    
    # Add cron job for performance monitoring (every hour)
    if ! crontab -l 2>/dev/null | grep -q "performance_monitor.sh"; then
        (crontab -l 2>/dev/null; echo "0 * * * * $MONITOR_SCRIPT") | crontab -
        log "Performance monitoring cron job added"
    fi
}

# Main execution
main() {
    log "=== Starting Performance Optimization ==="
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log "Warning: Not running as root. Some optimizations may not be applied."
    fi
    
    # Perform optimization tasks
    analyze_system_performance
    optimize_system_parameters
    optimize_disk_performance
    cleanup_system_resources
    optimize_database_performance
    optimize_network_performance
    optimize_filesystem_performance
    generate_performance_recommendations
    setup_performance_monitoring
    
    log "=== Performance Optimization Completed ==="
    log "Reports saved to: $REPORT_DIR"
    log "Log file: $LOG_FILE"
}

# Execute main function
main "$@"

