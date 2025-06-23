#!/bin/bash

# JIRA Integration Setup Script
# This script helps configure the JIRA integration with proper security

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env.jira"

echo "🔧 JIRA Integration Setup"
echo "=========================="

# Function to prompt for secure input
prompt_secure() {
    local prompt="$1"
    local var_name="$2"
    local current_value="$3"
    
    if [[ -n "$current_value" && "$current_value" != '""' ]]; then
        echo "✓ $prompt is already configured"
        return 0
    fi
    
    echo -n "$prompt: "
    read -s value
    echo
    
    if [[ -n "$value" ]]; then
        # Update the environment file
        sed -i "s|export $var_name=\".*\"|export $var_name=\"$value\"|" "$ENV_FILE"
        echo "✓ $prompt configured"
    else
        echo "⚠️  $prompt left empty"
    fi
}

# Function to prompt for regular input
prompt_regular() {
    local prompt="$1"
    local var_name="$2"
    local current_value="$3"
    
    if [[ -n "$current_value" && "$current_value" != '""' ]]; then
        echo "✓ $prompt: $current_value"
        return 0
    fi
    
    echo -n "$prompt: "
    read value
    
    if [[ -n "$value" ]]; then
        sed -i "s|export $var_name=\".*\"|export $var_name=\"$value\"|" "$ENV_FILE"
        echo "✓ $prompt configured: $value"
    else
        echo "⚠️  $prompt left empty"
    fi
}

# Check if environment file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ Environment file not found: $ENV_FILE"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Source current values
source "$ENV_FILE" 2>/dev/null || true

echo "📋 Current Configuration:"
echo "JIRA Base URL: ${JIRA_BASE_URL:-'Not set'}"
echo "JIRA Email: ${JIRA_EMAIL:-'Not set'}"
echo "JIRA Project Key: ${JIRA_PROJECT_KEY:-'Not set'}"
echo "GitHub Repository: ${GITHUB_REPOSITORY:-'Not set'}"
echo

# Configure each setting
echo "🔧 Configuration Setup:"
prompt_regular "JIRA Base URL (e.g., https://your-domain.atlassian.net)" "JIRA_BASE_URL" "${JIRA_BASE_URL:-}"
prompt_regular "JIRA Email" "JIRA_EMAIL" "${JIRA_EMAIL:-}"
prompt_regular "JIRA Project Key" "JIRA_PROJECT_KEY" "${JIRA_PROJECT_KEY:-}"
prompt_secure "JIRA API Token" "JIRA_API_TOKEN" "${JIRA_API_TOKEN:-}"
prompt_regular "GitHub Repository (user/repo)" "GITHUB_REPOSITORY" "${GITHUB_REPOSITORY:-}"
prompt_secure "GitHub Token (optional)" "GITHUB_TOKEN" "${GITHUB_TOKEN:-}"

echo
echo "🧪 Testing JIRA Connection..."

# Load the updated environment
source "$ENV_FILE"

# Test JIRA connection
if [[ -n "${JIRA_API_TOKEN:-}" && -n "${JIRA_BASE_URL:-}" && -n "${JIRA_EMAIL:-}" ]]; then
    echo "Testing authentication..."
    
    response=$(curl -s -w "%{http_code}" -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -X GET -H "Content-Type: application/json" \
        "${JIRA_BASE_URL}/rest/api/3/myself" -o /tmp/jira_test.json)
    
    if [[ "$response" == "200" ]]; then
        user_name=$(jq -r '.displayName // "Unknown"' /tmp/jira_test.json 2>/dev/null || echo "Unknown")
        echo "✅ JIRA connection successful! Authenticated as: $user_name"
        
        # Test project access
        echo "Testing project access..."
        project_response=$(curl -s -w "%{http_code}" -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
            -X GET -H "Content-Type: application/json" \
            "${JIRA_BASE_URL}/rest/api/3/project/${JIRA_PROJECT_KEY}" -o /tmp/jira_project.json)
        
        if [[ "$project_response" == "200" ]]; then
            project_name=$(jq -r '.name // "Unknown"' /tmp/jira_project.json 2>/dev/null || echo "Unknown")
            echo "✅ Project access confirmed: $project_name"
        else
            echo "⚠️  Project access test failed (HTTP $project_response)"
            echo "Please verify the JIRA_PROJECT_KEY is correct"
        fi
    else
        echo "❌ JIRA connection failed (HTTP $response)"
        echo "Please verify your credentials and URL"
    fi
    
    # Clean up temp files
    rm -f /tmp/jira_test.json /tmp/jira_project.json
else
    echo "⚠️  Skipping connection test - missing required credentials"
fi

echo
echo "📝 Next Steps:"
echo "1. Run 'source .env.jira' to load environment variables"
echo "2. Test the integration: './scripts/jira-integration.sh test'"
echo "3. Sync existing issues: './scripts/jira-integration.sh sync'"
echo
echo "📖 For more information, see PROJECT_TRACKING.md"
echo
echo "✅ Setup complete!"

