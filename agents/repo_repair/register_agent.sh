#!/bin/bash

# AI Agent Framework Registration Script for Repository Repair Tool
# This script registers the repo_repair tool with the AI agent framework

set -euo pipefail

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# Agent configuration
AGENT_NAME="repo_repair"
AGENT_VERSION="1.0.0"
AGENT_DESCRIPTION="Repository repair and maintenance tool"

# AI Agent Framework configuration
AI_FRAMEWORK_ENDPOINT="${AI_FRAMEWORK_ENDPOINT:-http://localhost:8080/api/v1}"
AI_FRAMEWORK_TOKEN="${AI_FRAMEWORK_TOKEN:-}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if AI framework is available
    if ! command -v curl &> /dev/null; then
        log "ERROR: curl is required but not installed"
        exit 1
    fi
    
    # Check if configuration files exist
    if [[ ! -f "${CONFIG_DIR}/agent_config.json" ]]; then
        log "ERROR: Agent configuration file not found at ${CONFIG_DIR}/agent_config.json"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Register tool with AI agent framework
register_tool() {
    log "Registering tool with AI agent framework..."
    
    # Create registration payload
    local registration_payload=$(cat "${CONFIG_DIR}/agent_config.json")
    
    # Add dynamic fields
    registration_payload=$(echo "$registration_payload" | jq \
        --arg name "$AGENT_NAME" \
        --arg version "$AGENT_VERSION" \
        --arg description "$AGENT_DESCRIPTION" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.name = $name | .version = $version | .description = $description | .registered_at = $timestamp')
    
    # Make registration API call
    local response
    if [[ -n "$AI_FRAMEWORK_TOKEN" ]]; then
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $AI_FRAMEWORK_TOKEN" \
            -d "$registration_payload" \
            "${AI_FRAMEWORK_ENDPOINT}/agents/register" || echo "ERROR")
    else
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$registration_payload" \
            "${AI_FRAMEWORK_ENDPOINT}/agents/register" || echo "ERROR")
    fi
    
    if [[ "$response" == "ERROR" ]]; then
        log "ERROR: Failed to register with AI framework"
        return 1
    fi
    
    # Parse response
    local status=$(echo "$response" | jq -r '.status // "unknown"')
    local agent_id=$(echo "$response" | jq -r '.agent_id // "unknown"')
    
    if [[ "$status" == "success" ]]; then
        log "Successfully registered agent with ID: $agent_id"
        echo "$agent_id" > "${CONFIG_DIR}/agent_id"
        return 0
    else
        log "ERROR: Registration failed with status: $status"
        log "Response: $response"
        return 1
    fi
}

# Update agent capabilities
update_capabilities() {
    log "Updating agent capabilities..."
    
    local agent_id
    if [[ -f "${CONFIG_DIR}/agent_id" ]]; then
        agent_id=$(cat "${CONFIG_DIR}/agent_id")
    else
        log "ERROR: Agent ID not found. Please register first."
        return 1
    fi
    
    # Update capabilities
    local capabilities_payload=$(cat "${CONFIG_DIR}/capabilities.json")
    
    local response
    if [[ -n "$AI_FRAMEWORK_TOKEN" ]]; then
        response=$(curl -s -X PUT \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $AI_FRAMEWORK_TOKEN" \
            -d "$capabilities_payload" \
            "${AI_FRAMEWORK_ENDPOINT}/agents/${agent_id}/capabilities" || echo "ERROR")
    else
        response=$(curl -s -X PUT \
            -H "Content-Type: application/json" \
            -d "$capabilities_payload" \
            "${AI_FRAMEWORK_ENDPOINT}/agents/${agent_id}/capabilities" || echo "ERROR")
    fi
    
    if [[ "$response" == "ERROR" ]]; then
        log "ERROR: Failed to update capabilities"
        return 1
    fi
    
    log "Successfully updated agent capabilities"
    return 0
}

# Generate service configuration
generate_service_config() {
    log "Generating service configuration..."
    
    local service_config=$(cat <<EOF
{
    "name": "$AGENT_NAME",
    "version": "$AGENT_VERSION",
    "description": "$AGENT_DESCRIPTION",
    "endpoints": {
        "health": "/health",
        "metrics": "/metrics",
        "execute": "/execute"
    },
    "port": 8081,
    "log_level": "INFO",
    "max_concurrent_jobs": 10,
    "timeout_seconds": 300
}
EOF
)
    
    echo "$service_config" > "${CONFIG_DIR}/service_config.json"
    log "Service configuration generated at ${CONFIG_DIR}/service_config.json"
}

# Main execution function
main() {
    log "Starting AI Agent Framework registration for $AGENT_NAME"
    
    check_prerequisites
    generate_service_config
    
    if register_tool; then
        update_capabilities
        log "Agent registration completed successfully"
    else
        log "ERROR: Agent registration failed"
        exit 1
    fi
    
    log "Registration process completed"
}

# Execute main function
main "$@"

