#!/bin/bash

# OCI Infrastructure Configuration Management Script
# This script manages and maintains system configurations using Ansible

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/oci-configuration-management.log"
CONFIG_BACKUP_DIR="/backup/configurations"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"
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
mkdir -p "$CONFIG_BACKUP_DIR" || true
mkdir -p "$ANSIBLE_DIR" || true

log "Starting configuration management cycle - $DATE"

# Function to setup Ansible if not present
setup_ansible() {
    log "Setting up Ansible configuration management..."
    
    # Check if Ansible is installed
    if ! command -v ansible &> /dev/null; then
        log "Installing Ansible..."
        if command -v pip3 &> /dev/null; then
            pip3 install ansible || error_exit "Failed to install Ansible"
        elif command -v yum &> /dev/null; then
            sudo yum install -y ansible || error_exit "Failed to install Ansible"
        elif command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y ansible || error_exit "Failed to install Ansible"
        else
            error_exit "No package manager found to install Ansible"
        fi
    fi
    
    # Create Ansible directory structure
    mkdir -p "$ANSIBLE_DIR"/{playbooks,inventory,roles,group_vars,host_vars}
    
    # Create ansible.cfg
    cat > "$ANSIBLE_DIR/ansible.cfg" << EOF
[defaults]
inventory = inventory/hosts.ini
host_key_checking = False
log_path = /var/log/ansible.log
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts_cache
fact_caching_timeout = 86400
retry_files_enabled = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF

    log "Ansible setup completed"
}

# Function to create inventory file
create_inventory() {
    log "Creating Ansible inventory..."
    
    cat > "$ANSIBLE_DIR/inventory/hosts.ini" << EOF
[oci_instances]
localhost ansible_connection=local

[oci_instances:vars]
ansible_user=opc
ansible_ssh_private_key_file=~/.ssh/id_rsa

[databases]
# Add database servers here

[web_servers]
# Add web servers here

[load_balancers]
# Add load balancers here

[all:vars]
# Global variables
environment=production
backup_retention_days=30
log_level=INFO
EOF

    log "Inventory file created"
}

# Function to create configuration management playbooks
create_playbooks() {
    log "Creating Ansible playbooks..."
    
    # Main site configuration playbook
    cat > "$ANSIBLE_DIR/playbooks/site.yml" << EOF
---
- name: OCI Infrastructure Configuration Management
  hosts: all
  become: yes
  gather_facts: yes
  
  roles:
    - common
    - security
    - monitoring
    - backup

- name: Database Configuration
  hosts: databases
  become: yes
  roles:
    - database

- name: Web Server Configuration
  hosts: web_servers
  become: yes
  roles:
    - webserver

- name: Load Balancer Configuration
  hosts: load_balancers
  become: yes
  roles:
    - loadbalancer
EOF

    # Security hardening playbook
    cat > "$ANSIBLE_DIR/playbooks/security_hardening.yml" << EOF
---
- name: Security Hardening
  hosts: all
  become: yes
  tasks:
    - name: Update all packages
      package:
        name: "*"
        state: latest
      when: ansible_os_family == "RedHat"
    
    - name: Update all packages (Debian/Ubuntu)
      apt:
        upgrade: dist
        update_cache: yes
      when: ansible_os_family == "Debian"
    
    - name: Configure SSH hardening
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
        backup: yes
      loop:
        - { regexp: '^#?PermitRootLogin', line: 'PermitRootLogin no' }
        - { regexp: '^#?PasswordAuthentication', line: 'PasswordAuthentication no' }
        - { regexp: '^#?X11Forwarding', line: 'X11Forwarding no' }
        - { regexp: '^#?MaxAuthTries', line: 'MaxAuthTries 3' }
      notify: restart sshd
    
    - name: Configure firewall
      firewalld:
        service: "{{ item }}"
        permanent: yes
        state: enabled
        immediate: yes
      loop:
        - ssh
        - http
        - https
      when: ansible_os_family == "RedHat"
    
    - name: Install fail2ban
      package:
        name: fail2ban
        state: present
    
    - name: Configure fail2ban
      copy:
        dest: /etc/fail2ban/jail.local
        content: |
          [DEFAULT]
          bantime = 3600
          findtime = 600
          maxretry = 3
          
          [sshd]
          enabled = true
          port = ssh
          logpath = /var/log/auth.log
          maxretry = 3
      notify: restart fail2ban
  
  handlers:
    - name: restart sshd
      service:
        name: sshd
        state: restarted
    
    - name: restart fail2ban
      service:
        name: fail2ban
        state: restarted
EOF

    # System monitoring playbook
    cat > "$ANSIBLE_DIR/playbooks/monitoring_setup.yml" << EOF
---
- name: Setup System Monitoring
  hosts: all
  become: yes
  tasks:
    - name: Install monitoring tools
      package:
        name:
          - htop
          - iotop
          - netstat-nat
          - tcpdump
          - sysstat
        state: present
    
    - name: Configure logrotate
      copy:
        dest: /etc/logrotate.d/custom-apps
        content: |
          /var/log/applications/*.log {
              daily
              missingok
              rotate 30
              compress
              delaycompress
              notifempty
              create 0644 root root
          }
    
    - name: Setup cron for system monitoring
      cron:
        name: "System monitoring"
        minute: "*/5"
        job: "/usr/bin/iostat -x 1 1 >> /var/log/iostat.log"
        user: root
EOF

    # Backup configuration playbook
    cat > "$ANSIBLE_DIR/playbooks/backup_setup.yml" << EOF
---
- name: Setup Backup Procedures
  hosts: all
  become: yes
  vars:
    backup_dirs:
      - /etc
      - /home
      - /var/log
      - /opt
    backup_destination: /backup
  
  tasks:
    - name: Create backup directories
      file:
        path: "{{ backup_destination }}/{{ inventory_hostname }}"
        state: directory
        mode: '0755'
    
    - name: Install backup tools
      package:
        name:
          - rsync
          - tar
          - gzip
        state: present
    
    - name: Create backup script
      template:
        src: backup_script.sh.j2
        dest: /usr/local/bin/backup_system.sh
        mode: '0755'
    
    - name: Setup daily backup cron job
      cron:
        name: "Daily system backup"
        minute: "0"
        hour: "2"
        job: "/usr/local/bin/backup_system.sh"
        user: root
EOF

    log "Playbooks created"
}

# Function to create Ansible roles
create_roles() {
    log "Creating Ansible roles..."
    
    # Common role
    mkdir -p "$ANSIBLE_DIR/roles/common"/{tasks,handlers,templates,files,vars,defaults}
    
    cat > "$ANSIBLE_DIR/roles/common/tasks/main.yml" << EOF
---
- name: Update package cache
  package:
    name: "*"
    state: latest
  when: ansible_os_family == "RedHat"

- name: Update package cache (Debian/Ubuntu)
  apt:
    update_cache: yes
    upgrade: dist
  when: ansible_os_family == "Debian"

- name: Install common packages
  package:
    name:
      - vim
      - curl
      - wget
      - git
      - htop
      - tree
      - unzip
    state: present

- name: Configure timezone
  timezone:
    name: UTC

- name: Configure NTP
  service:
    name: "{{ ntp_service }}"
    state: started
    enabled: yes
  vars:
    ntp_service: "{{ 'chronyd' if ansible_os_family == 'RedHat' else 'ntp' }}"
EOF

    # Security role
    mkdir -p "$ANSIBLE_DIR/roles/security"/{tasks,handlers,templates,files,vars,defaults}
    
    cat > "$ANSIBLE_DIR/roles/security/tasks/main.yml" << EOF
---
- name: Configure sudo
  lineinfile:
    path: /etc/sudoers
    regexp: '^%wheel'
    line: '%wheel ALL=(ALL) NOPASSWD: ALL'
    validate: 'visudo -cf %s'
  when: ansible_os_family == "RedHat"

- name: Configure auditd
  package:
    name: audit
    state: present
  when: ansible_os_family == "RedHat"

- name: Start auditd service
  service:
    name: auditd
    state: started
    enabled: yes
  when: ansible_os_family == "RedHat"

- name: Configure file permissions
  file:
    path: "{{ item }}"
    mode: '0600'
  loop:
    - /etc/ssh/sshd_config
    - /etc/shadow
  ignore_errors: yes
EOF

    log "Roles created"
}

# Function to backup current configurations
backup_configurations() {
    log "Backing up current configurations..."
    
    BACKUP_DIR="$CONFIG_BACKUP_DIR/config_backup_$DATE"
    mkdir -p "$BACKUP_DIR"
    
    # Backup important configuration files
    CONFIG_FILES=(
        "/etc/ssh/sshd_config"
        "/etc/sudoers"
        "/etc/crontab"
        "/etc/fstab"
        "/etc/hosts"
        "/etc/resolv.conf"
        "/etc/systemd"
        "/etc/nginx"
        "/etc/apache2"
        "/etc/mysql"
        "/etc/postgresql"
    )
    
    for config in "${CONFIG_FILES[@]}"; do
        if [ -f "$config" ] || [ -d "$config" ]; then
            log "Backing up $config"
            cp -r "$config" "$BACKUP_DIR/" 2>/dev/null || log "Warning: Failed to backup $config"
        fi
    done
    
    # Create backup inventory
    cat > "$BACKUP_DIR/backup_inventory.txt" << EOF
Configuration Backup Inventory
Created: $(date)
Hostname: $(hostname)
Backup Location: $BACKUP_DIR

Files and directories backed up:
EOF
    
    find "$BACKUP_DIR" -type f | sort >> "$BACKUP_DIR/backup_inventory.txt"
    
    log "Configuration backup completed: $BACKUP_DIR"
}

# Function to apply configurations
apply_configurations() {
    log "Applying configurations with Ansible..."
    
    cd "$ANSIBLE_DIR"
    
    # Check Ansible syntax
    if ansible-playbook playbooks/site.yml --syntax-check; then
        log "Ansible syntax check passed"
    else
        error_exit "Ansible syntax check failed"
    fi
    
    # Run in check mode first
    log "Running Ansible in check mode..."
    if ansible-playbook playbooks/site.yml --check --diff; then
        log "Ansible check mode completed successfully"
    else
        log "Warning: Ansible check mode reported issues"
    fi
    
    # Apply configurations
    log "Applying configurations..."
    if ansible-playbook playbooks/site.yml --diff; then
        log "Configuration application completed successfully"
    else
        error_exit "Configuration application failed"
    fi
}

# Function to verify configurations
verify_configurations() {
    log "Verifying applied configurations..."
    
    # Check critical services
    SERVICES=("sshd" "chronyd" "firewalld")
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-active "$service" &> /dev/null; then
            log "Service $service is active"
        else
            log "Warning: Service $service is not active"
        fi
    done
    
    # Check SSH configuration
    if sshd -t; then
        log "SSH configuration is valid"
    else
        log "Warning: SSH configuration has issues"
    fi
    
    # Check firewall status
    if command -v firewall-cmd &> /dev/null; then
        FIREWALL_STATUS=$(firewall-cmd --state 2>/dev/null || echo "not running")
        log "Firewall status: $FIREWALL_STATUS"
    fi
    
    # Generate verification report
    VERIFY_REPORT="$CONFIG_BACKUP_DIR/verification_report_$DATE.txt"
    
    cat > "$VERIFY_REPORT" << EOF
Configuration Verification Report
Generated: $(date)
Hostname: $(hostname)

=== Service Status ===
$(systemctl list-units --type=service --state=active | head -20)

=== Network Configuration ===
$(ip addr show)

=== SSH Configuration Test ===
$(sshd -t 2>&1 || echo "SSH configuration test failed")

=== Firewall Status ===
$(firewall-cmd --list-all 2>/dev/null || echo "Firewall not configured")

=== Cron Jobs ===
$(crontab -l 2>/dev/null || echo "No cron jobs")

=== Mounted Filesystems ===
$(mount | column -t)

EOF

    log "Verification report saved to $VERIFY_REPORT"
}

# Function to create maintenance schedule
create_maintenance_schedule() {
    log "Creating maintenance schedule..."
    
    # Create cron jobs for regular maintenance
    CRON_JOBS=(
        "0 2 * * 0 $SCRIPT_DIR/configuration_management.sh apply"
        "0 3 * * * $SCRIPT_DIR/security_updates.sh"
        "0 4 * * * $SCRIPT_DIR/performance_optimization.sh"
        "0 1 * * 0 $SCRIPT_DIR/backup_procedures.sh"
    )
    
    for job in "${CRON_JOBS[@]}"; do
        if ! crontab -l 2>/dev/null | grep -q "${job#* * * * * }"; then
            (crontab -l 2>/dev/null; echo "$job") | crontab -
            log "Added cron job: $job"
        fi
    done
    
    # Create systemd timers as alternative
    TIMER_DIR="/etc/systemd/system"
    
    cat > "$TIMER_DIR/oci-config-management.service" << EOF
[Unit]
Description=OCI Configuration Management
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/configuration_management.sh apply
User=root
EOF

    cat > "$TIMER_DIR/oci-config-management.timer" << EOF
[Unit]
Description=Run OCI Configuration Management weekly
Requires=oci-config-management.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable oci-config-management.timer
    systemctl start oci-config-management.timer
    
    log "Maintenance schedule created"
}

# Function to generate configuration report
generate_config_report() {
    log "Generating configuration management report..."
    
    REPORT_FILE="$CONFIG_BACKUP_DIR/config_management_report_$DATE.txt"
    
    cat > "$REPORT_FILE" << EOF
OCI Infrastructure Configuration Management Report
Generated: $(date)
Hostname: $(hostname)

=== Ansible Version ===
$(ansible --version)

=== Managed Configurations ===
- SSH hardening
- Firewall configuration
- System monitoring
- Backup procedures
- Security policies
- Performance optimizations

=== Applied Playbooks ===
$(find "$ANSIBLE_DIR/playbooks" -name "*.yml" -exec basename {} \; | sort)

=== Configuration Changes ===
Last configuration backup: $BACKUP_DIR
Last configuration apply: $(date)

=== System Status ===
Uptime: $(uptime)
Load: $(cat /proc/loadavg)
Memory: $(free -h | grep Mem)
Disk: $(df -h / | tail -1)

=== Security Status ===
SSH Root Login: $(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "Not configured")
Firewall Status: $(systemctl is-active firewalld 2>/dev/null || echo "Not active")
Fail2ban Status: $(systemctl is-active fail2ban 2>/dev/null || echo "Not active")

=== Scheduled Maintenance ===
$(crontab -l 2>/dev/null | grep -E "(security|performance|backup|config)" || echo "No scheduled maintenance found")

EOF

    log "Configuration report saved to $REPORT_FILE"
}

# Main execution
main() {
    log "=== Starting Configuration Management ==="
    
    case "${1:-setup}" in
        "setup")
            setup_ansible
            create_inventory
            create_playbooks
            create_roles
            create_maintenance_schedule
            ;;
        "backup")
            backup_configurations
            ;;
        "apply")
            backup_configurations
            apply_configurations
            verify_configurations
            ;;
        "verify")
            verify_configurations
            ;;
        "report")
            generate_config_report
            ;;
        *)
            log "Usage: $0 {setup|backup|apply|verify|report}"
            exit 1
            ;;
    esac
    
    generate_config_report
    
    log "=== Configuration Management Completed ==="
    log "Log file: $LOG_FILE"
    log "Backups: $CONFIG_BACKUP_DIR"
}

# Execute main function
main "$@"

