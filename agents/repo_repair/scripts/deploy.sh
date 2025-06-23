#!/bin/bash

# Deployment and Installation Script for Repository Repair Agent
# This script handles the complete deployment and integration process

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$(dirname "$PARENT_DIR")")"

# Default configuration
DEFAULT_INSTALL_DIR="/opt/repo-repair"
DEFAULT_SERVICE_USER="repo-repair"
DEFAULT_AI_FRAMEWORK_ENDPOINT="http://localhost:8080/api/v1"

# Command line arguments
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
SERVICE_USER="${SERVICE_USER:-$DEFAULT_SERVICE_USER}"
AI_FRAMEWORK_ENDPOINT="${AI_FRAMEWORK_ENDPOINT:-$DEFAULT_AI_FRAMEWORK_ENDPOINT}"
DRY_RUN="${DRY_RUN:-false}"
FORCE_INSTALL="${FORCE_INSTALL:-false}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Show usage information
show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Deploy and install the Repository Repair Agent

OPTIONS:
    --install-dir DIR          Installation directory (default: $DEFAULT_INSTALL_DIR)
    --service-user USER        Service user (default: $DEFAULT_SERVICE_USER)
    --ai-endpoint URL          AI Framework endpoint (default: $DEFAULT_AI_FRAMEWORK_ENDPOINT)
    --dry-run                  Show what would be done without executing
    --force                    Force installation even if already installed
    --help                     Show this help message

ENVIRONMENT VARIABLES:
    INSTALL_DIR               Installation directory
    SERVICE_USER              Service user
    AI_FRAMEWORK_ENDPOINT     AI Framework endpoint
    AI_FRAMEWORK_TOKEN        AI Framework authentication token
    DRY_RUN                   Set to 'true' for dry run mode
    FORCE_INSTALL             Set to 'true' to force installation

EXAMPLES:
    # Basic installation
    $0

    # Custom installation directory
    $0 --install-dir /usr/local/repo-repair

    # Dry run to see what would happen
    $0 --dry-run

    # Force reinstallation
    $0 --force
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --service-user)
                SERVICE_USER="$2"
                shift 2
                ;;
            --ai-endpoint)
                AI_FRAMEWORK_ENDPOINT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --force)
                FORCE_INSTALL="true"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log "ERROR: Unknown option $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Execute command with dry run support
execute() {
    local cmd="$1"
    local description="$2"
    
    log "$description"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: $cmd"
        return 0
    fi
    
    if eval "$cmd"; then
        log "SUCCESS: $description"
        return 0
    else
        log "ERROR: Failed to $description"
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log "ERROR: This script requires root privileges or passwordless sudo"
        log "Please run with sudo or configure passwordless sudo for your user"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("git" "curl" "jq" "systemctl")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log "ERROR: Missing required commands: ${missing_commands[*]}"
        log "Please install them before continuing"
        exit 1
    fi
    
    # Check if AI framework is accessible
    if ! curl -s --connect-timeout 5 "$AI_FRAMEWORK_ENDPOINT/health" &> /dev/null; then
        log "WARNING: AI Framework not accessible at $AI_FRAMEWORK_ENDPOINT"
        log "The agent will be installed but may not function until the framework is available"
    fi
    
    log "Prerequisites check completed"
}

# Check if already installed
check_existing_installation() {
    if [[ -d "$INSTALL_DIR" ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
        log "ERROR: Installation directory $INSTALL_DIR already exists"
        log "Use --force to overwrite or choose a different directory"
        exit 1
    fi
    
    if systemctl is-active --quiet repo-repair.service 2>/dev/null && [[ "$FORCE_INSTALL" != "true" ]]; then
        log "ERROR: Repository Repair service is already running"
        log "Use --force to reinstall or stop the service first"
        exit 1
    fi
}

# Create service user
create_service_user() {
    if id "$SERVICE_USER" &>/dev/null; then
        log "Service user $SERVICE_USER already exists"
        return 0
    fi
    
    execute "useradd --system --home-dir $INSTALL_DIR --shell /bin/bash --comment 'Repository Repair Agent' $SERVICE_USER" \
            "Creating service user $SERVICE_USER"
}

# Install agent files
install_agent() {
    log "Installing Repository Repair Agent..."
    
    # Create installation directory
    execute "mkdir -p $INSTALL_DIR" "Creating installation directory"
    
    # Copy agent files
    execute "cp -r $PARENT_DIR/* $INSTALL_DIR/" "Copying agent files"
    
    # Set ownership and permissions
    execute "chown -R $SERVICE_USER:$SERVICE_USER $INSTALL_DIR" "Setting file ownership"
    execute "chmod +x $INSTALL_DIR/register_agent.sh" "Setting execute permissions"
    execute "chmod +x $INSTALL_DIR/scripts/*.sh" "Setting script permissions"
    
    # Create log directory
    execute "mkdir -p /var/log/repo-repair" "Creating log directory"
    execute "chown $SERVICE_USER:$SERVICE_USER /var/log/repo-repair" "Setting log directory ownership"
    
    # Create symlink for global access
    execute "ln -sf $INSTALL_DIR/register_agent.sh /usr/local/bin/repo-repair" "Creating global command symlink"
    
    log "Agent installation completed"
}

# Configure environment
configure_environment() {
    log "Configuring environment..."
    
    # Create environment file
    local env_file="$INSTALL_DIR/.env"
    
    cat > "$env_file" <<EOF
# Repository Repair Agent Environment Configuration
AI_FRAMEWORK_ENDPOINT=$AI_FRAMEWORK_ENDPOINT
AI_FRAMEWORK_TOKEN=${AI_FRAMEWORK_TOKEN:-}
REPO_REPAIR_LOG_LEVEL=INFO
REPO_REPAIR_TIMEOUT=300
REPO_REPAIR_MAX_RETRIES=3
REPO_REPAIR_PORT=8081
REPO_REPAIR_HOST=0.0.0.0
INSTALL_DIR=$INSTALL_DIR
EOF
    
    execute "chown $SERVICE_USER:$SERVICE_USER $env_file" "Setting environment file ownership"
    execute "chmod 600 $env_file" "Setting environment file permissions"
    
    log "Environment configuration completed"
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service..."
    
    local service_file="/etc/systemd/system/repo-repair.service"
    
    cat > "$service_file" <<EOF
[Unit]
Description=Repository Repair Agent
After=network.target
Requires=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/register_agent.sh
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
EnvironmentFile=$INSTALL_DIR/.env
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    execute "systemctl daemon-reload" "Reloading systemd configuration"
    execute "systemctl enable repo-repair.service" "Enabling repo-repair service"
    
    log "Systemd service created and enabled"
}

# Run package integration
run_package_integration() {
    log "Running package management integration..."
    
    local integration_script="$INSTALL_DIR/scripts/package_integration.sh"
    
    if [[ -f "$integration_script" ]]; then
        execute "bash $integration_script" "Running package integration"
    else
        log "WARNING: Package integration script not found"
    fi
}

# Register with AI framework
register_with_framework() {
    log "Registering with AI framework..."
    
    # Set environment variables for registration
    export AI_FRAMEWORK_ENDPOINT
    export AI_FRAMEWORK_TOKEN
    
    local register_script="$INSTALL_DIR/register_agent.sh"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would register agent with AI framework"
        return 0
    fi
    
    # Try to register (may fail if framework is not available)
    if sudo -u "$SERVICE_USER" bash "$register_script"; then
        log "Successfully registered with AI framework"
    else
        log "WARNING: Failed to register with AI framework"
        log "The agent is installed but not registered. Try registering manually later."
    fi
}

# Start services
start_services() {
    log "Starting services..."
    
    execute "systemctl start repo-repair.service" "Starting repo-repair service"
    
    # Wait a moment and check status
    sleep 2
    
    if systemctl is-active --quiet repo-repair.service; then
        log "Repository Repair Agent is running successfully"
    else
        log "WARNING: Repository Repair Agent failed to start"
        if [[ "$DRY_RUN" != "true" ]]; then
            log "Service status:"
            systemctl status repo-repair.service --no-pager || true
        fi
    fi
}

# Show installation summary
show_summary() {
    log "Installation Summary:"
    log "===================="
    log "Installation Directory: $INSTALL_DIR"
    log "Service User: $SERVICE_USER"
    log "AI Framework Endpoint: $AI_FRAMEWORK_ENDPOINT"
    log "Global Command: repo-repair"
    log "Service: repo-repair.service"
    log "Logs: /var/log/repo-repair/"
    log ""
    log "Usage:"
    log "  # Check service status"
    log "  systemctl status repo-repair.service"
    log ""
    log "  # View logs"
    log "  journalctl -u repo-repair.service -f"
    log ""
    log "  # Run manually"
    log "  repo-repair --help"
    log ""
    log "Installation completed successfully!"
}

# Cleanup on error
cleanup_on_error() {
    log "ERROR: Installation failed. Cleaning up..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Stop service if it exists
        systemctl stop repo-repair.service 2>/dev/null || true
        systemctl disable repo-repair.service 2>/dev/null || true
        
        # Remove service file
        rm -f /etc/systemd/system/repo-repair.service
        
        # Remove installation directory
        rm -rf "$INSTALL_DIR"
        
        # Remove global symlink
        rm -f /usr/local/bin/repo-repair
        
        # Remove service user (but be careful)
        if [[ "$SERVICE_USER" != "root" ]] && [[ "$SERVICE_USER" != "$(whoami)" ]]; then
            userdel "$SERVICE_USER" 2>/dev/null || true
        fi
        
        systemctl daemon-reload
    fi
    
    exit 1
}

# Main deployment function
main() {
    log "Starting Repository Repair Agent deployment..."
    
    # Set trap for cleanup on error
    trap cleanup_on_error ERR
    
    parse_arguments "$@"
    check_prerequisites
    check_existing_installation
    create_service_user
    install_agent
    configure_environment
    create_systemd_service
    run_package_integration
    register_with_framework
    start_services
    show_summary
    
    # Remove error trap
    trap - ERR
    
    log "Deployment completed successfully!"
}

# Execute main function
main "$@"

