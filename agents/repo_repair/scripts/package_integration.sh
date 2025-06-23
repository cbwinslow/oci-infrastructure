#!/bin/bash

# Package Management Integration Script for Repository Repair Tool
# This script integrates the repo_repair tool with various package management systems

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${PARENT_DIR}/config"
TEMPLATES_DIR="${PARENT_DIR}/templates"

# Package management systems to integrate with
PACKAGE_MANAGERS=("apt" "yum" "dnf" "pacman" "brew" "pip" "npm" "docker")

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Detect available package managers
detect_package_managers() {
    log "Detecting available package managers..."
    
    local available_managers=()
    
    for manager in "${PACKAGE_MANAGERS[@]}"; do
        if command -v "$manager" &> /dev/null; then
            available_managers+=("$manager")
            log "Found package manager: $manager"
        fi
    done
    
    if [ ${#available_managers[@]} -eq 0 ]; then
        log "WARNING: No supported package managers found"
        return 1
    fi
    
    echo "${available_managers[@]}"
    return 0
}

# Create APT package configuration
create_apt_package() {
    log "Creating APT package configuration..."
    
    local package_dir="${TEMPLATES_DIR}/apt"
    mkdir -p "$package_dir"
    
    cat > "${package_dir}/repo-repair.install" <<EOF
#!/bin/bash
# APT package installation script for repo-repair

set -e

# Installation directories
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/repo-repair"
LOG_DIR="/var/log/repo-repair"
SERVICE_DIR="/etc/systemd/system"

# Create directories
mkdir -p "\$CONFIG_DIR" "\$LOG_DIR"

# Copy files
cp -r agents/repo_repair/* "\$CONFIG_DIR/"
chmod +x "\$CONFIG_DIR/scripts/"*.sh
chmod +x "\$CONFIG_DIR/register_agent.sh"

# Create symlink
ln -sf "\$CONFIG_DIR/register_agent.sh" "\$INSTALL_DIR/repo-repair"

# Create systemd service
cat > "\$SERVICE_DIR/repo-repair.service" <<SERVICE_EOF
[Unit]
Description=Repository Repair Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=\$CONFIG_DIR/register_agent.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable repo-repair.service

echo "Repository Repair Agent installed successfully"
EOF

    chmod +x "${package_dir}/repo-repair.install"
    
    # Create control file
    cat > "${package_dir}/control" <<EOF
Package: repo-repair
Version: 1.0.0
Architecture: all
Maintainer: cbwinslow <blaine.winslow@gmail.com>
Description: Repository repair and maintenance tool
 A comprehensive tool for repairing and maintaining Git repositories,
 including permission fixes, synchronization, and change handling.
Depends: git, jq, curl
Section: utils
Priority: optional
EOF
    
    log "APT package configuration created"
}

# Create Docker package configuration
create_docker_package() {
    log "Creating Docker package configuration..."
    
    local docker_dir="${TEMPLATES_DIR}/docker"
    mkdir -p "$docker_dir"
    
    cat > "${docker_dir}/Dockerfile" <<EOF
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \\
    git \\
    jq \\
    curl \\
    bash \\
    coreutils \\
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /app

# Copy application files
COPY agents/repo_repair/ .

# Set permissions
RUN chmod +x scripts/*.sh && \\
    chmod +x register_agent.sh

# Create non-root user
RUN useradd -m -s /bin/bash repo-repair
USER repo-repair

# Expose port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:8081/health || exit 1

# Start the service
CMD ["./register_agent.sh"]
EOF

    # Create docker-compose file
    cat > "${docker_dir}/docker-compose.yml" <<EOF
version: '3.8'

services:
  repo-repair:
    build: .
    container_name: repo-repair-agent
    ports:
      - "8081:8081"
    environment:
      - AI_FRAMEWORK_ENDPOINT=http://ai-framework:8080/api/v1
      - REPO_REPAIR_LOG_LEVEL=INFO
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config
    restart: unless-stopped
    networks:
      - ai-agents

  ai-framework:
    image: ai-framework:latest
    container_name: ai-framework
    ports:
      - "8080:8080"
    environment:
      - FRAMEWORK_MODE=production
    networks:
      - ai-agents

networks:
  ai-agents:
    external: true
EOF

    log "Docker package configuration created"
}

# Create NPM package configuration
create_npm_package() {
    log "Creating NPM package configuration..."
    
    local npm_dir="${TEMPLATES_DIR}/npm"
    mkdir -p "$npm_dir"
    
    cat > "${npm_dir}/package.json" <<EOF
{
  "name": "repo-repair-agent",
  "version": "1.0.0",
  "description": "Repository repair and maintenance tool",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "install-agent": "bash install.sh",
    "register": "bash register_agent.sh",
    "test": "bash test.sh"
  },
  "keywords": [
    "repository",
    "repair",
    "maintenance",
    "git",
    "devops",
    "ai-agent"
  ],
  "author": "cbwinslow <blaine.winslow@gmail.com>",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.0",
    "axios": "^1.4.0",
    "winston": "^3.8.0"
  },
  "engines": {
    "node": ">=16.0.0"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/cbwinslow/oci-infrastructure.git"
  },
  "bin": {
    "repo-repair": "./bin/repo-repair"
  }
}
EOF

    # Create wrapper script
    mkdir -p "${npm_dir}/bin"
    cat > "${npm_dir}/bin/repo-repair" <<EOF
#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

const scriptPath = path.join(__dirname, '..', 'register_agent.sh');
const child = spawn('bash', [scriptPath, ...process.argv.slice(2)], {
    stdio: 'inherit'
});

child.on('exit', (code) => {
    process.exit(code);
});
EOF

    chmod +x "${npm_dir}/bin/repo-repair"
    
    log "NPM package configuration created"
}

# Create configuration templates
create_config_templates() {
    log "Creating configuration templates..."
    
    # Create environment template
    cat > "${TEMPLATES_DIR}/env.template" <<EOF
# Repository Repair Agent Environment Configuration

# AI Framework Configuration
AI_FRAMEWORK_ENDPOINT=http://localhost:8080/api/v1
AI_FRAMEWORK_TOKEN=

# Agent Configuration
REPO_REPAIR_LOG_LEVEL=INFO
REPO_REPAIR_TIMEOUT=300
REPO_REPAIR_MAX_RETRIES=3

# Service Configuration
REPO_REPAIR_PORT=8081
REPO_REPAIR_HOST=0.0.0.0

# Security Configuration
REPO_REPAIR_SANDBOX=true
REPO_REPAIR_ALLOWED_PATHS=/tmp,/var/tmp,\${HOME}/.git

# Notification Configuration
REPO_REPAIR_WEBHOOK_URL=
REPO_REPAIR_SLACK_WEBHOOK=
REPO_REPAIR_EMAIL_SMTP=

# Monitoring Configuration
REPO_REPAIR_METRICS_ENABLED=true
REPO_REPAIR_HEALTH_CHECK_INTERVAL=30
EOF

    # Create systemd service template
    cat > "${TEMPLATES_DIR}/repo-repair.service.template" <<EOF
[Unit]
Description=Repository Repair Agent
After=network.target
Requires=network.target

[Service]
Type=simple
User=\${SERVICE_USER}
Group=\${SERVICE_GROUP}
WorkingDirectory=\${INSTALL_DIR}
ExecStart=\${INSTALL_DIR}/register_agent.sh
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
Environment=AI_FRAMEWORK_ENDPOINT=\${AI_FRAMEWORK_ENDPOINT}
Environment=REPO_REPAIR_LOG_LEVEL=\${REPO_REPAIR_LOG_LEVEL}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create cron template
    cat > "${TEMPLATES_DIR}/crontab.template" <<EOF
# Repository Repair Agent Cron Jobs
# Syntax: minute hour day month day-of-week command

# Run repository sync every hour
0 * * * * \${INSTALL_DIR}/scripts/sync_repos.sh --auto

# Run permission fix daily at 2 AM
0 2 * * * \${INSTALL_DIR}/scripts/fix_permissions.sh --auto

# Health check every 5 minutes
*/5 * * * * \${INSTALL_DIR}/scripts/health_check.sh
EOF

    log "Configuration templates created"
}

# Set up automated triggers
setup_automated_triggers() {
    log "Setting up automated triggers..."
    
    local triggers_dir="${TEMPLATES_DIR}/triggers"
    mkdir -p "$triggers_dir"
    
    # Git hooks
    cat > "${triggers_dir}/post-receive" <<EOF
#!/bin/bash
# Git post-receive hook for repository repair agent

# Trigger repository repair after push
\${INSTALL_DIR}/scripts/handle_changes.sh --repo-path=\$(pwd) --change-type=commit --auto-commit=false
EOF

    # GitHub Actions workflow
    cat > "${triggers_dir}/repo-repair.yml" <<EOF
name: Repository Repair Agent

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  repair:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Repository Repair Agent
      run: |
        curl -sSL https://raw.githubusercontent.com/cbwinslow/oci-infrastructure/main/agents/repo_repair/scripts/package_integration.sh | bash
        
    - name: Run Repository Repair
      run: |
        repo-repair --repo-path=\${{ github.workspace }} --auto-fix=true
        
    - name: Upload Logs
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: repair-logs
        path: logs/
EOF

    # Webhook handler
    cat > "${triggers_dir}/webhook_handler.sh" <<EOF
#!/bin/bash
# Webhook handler for repository repair agent

set -euo pipefail

# Parse webhook payload
PAYLOAD=\$(cat)
EVENT_TYPE=\$(echo "\$PAYLOAD" | jq -r '.action // .event_type // "unknown"')
REPO_URL=\$(echo "\$PAYLOAD" | jq -r '.repository.clone_url // .repo_url // ""')

case "\$EVENT_TYPE" in
    "push"|"commit")
        # Handle push events
        \${INSTALL_DIR}/scripts/handle_changes.sh --repo-url="\$REPO_URL" --change-type=commit
        ;;
    "pull_request")
        # Handle pull request events
        \${INSTALL_DIR}/scripts/sync_repos.sh --repo-url="\$REPO_URL" --force-sync=false
        ;;
    "repository")
        # Handle repository events
        \${INSTALL_DIR}/scripts/fix_permissions.sh --repo-url="\$REPO_URL"
        ;;
    *)
        echo "Unknown event type: \$EVENT_TYPE"
        ;;
esac
EOF

    chmod +x "${triggers_dir}"/*.sh
    
    log "Automated triggers set up"
}

# Main integration function
main() {
    log "Starting package management integration..."
    
    # Detect available package managers
    local available_managers
    if ! available_managers=$(detect_package_managers); then
        log "ERROR: No package managers detected"
        exit 1
    fi
    
    # Create package configurations
    for manager in $available_managers; do
        case "$manager" in
            "apt"|"yum"|"dnf")
                create_apt_package
                ;;
            "docker")
                create_docker_package
                ;;
            "npm")
                create_npm_package
                ;;
        esac
    done
    
    # Create configuration templates
    create_config_templates
    
    # Set up automated triggers
    setup_automated_triggers
    
    log "Package management integration completed successfully"
    log "Available integrations: $available_managers"
}

# Execute main function
main "$@"

