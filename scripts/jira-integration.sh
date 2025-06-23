#!/bin/bash

# JIRA Integration Script for GitHub Issues
# This script facilitates synchronization between GitHub Issues and JIRA tickets

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/logs/jira-integration.log"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check required environment variables
check_env_vars() {
    local required_vars=(
        "JIRA_BASE_URL"
        "JIRA_EMAIL"
        "JIRA_API_TOKEN"
        "JIRA_PROJECT_KEY"
        "GITHUB_TOKEN"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error_exit "Required environment variable $var is not set"
        fi
    done
}

# JIRA API functions
jira_api_call() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    local curl_args=(
        -s
        -X "$method"
        -H "Accept: application/json"
        -H "Content-Type: application/json"
        -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}"
    )
    
    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi
    
    curl "${curl_args[@]}" "${JIRA_BASE_URL}/rest/api/3/${endpoint}"
}

# GitHub API functions
github_api_call() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    local curl_args=(
        -s
        -X "$method"
        -H "Accept: application/vnd.github.v3+json"
        -H "Authorization: token ${GITHUB_TOKEN}"
    )
    
    if [[ -n "$data" ]]; then
        curl_args+=(-H "Content-Type: application/json" -d "$data")
    fi
    
    curl "${curl_args[@]}" "https://api.github.com/${endpoint}"
}

# Convert GitHub issue to JIRA ticket
create_jira_ticket() {
    local github_issue="$1"
    
    # Extract issue details using jq
    local title=$(echo "$github_issue" | jq -r '.title')
    local body=$(echo "$github_issue" | jq -r '.body // ""')
    local issue_number=$(echo "$github_issue" | jq -r '.number')
    local html_url=$(echo "$github_issue" | jq -r '.html_url')
    local labels=$(echo "$github_issue" | jq -r '.labels[].name' | tr '\n' ',' | sed 's/,$//')
    
    # Determine issue type based on labels
    local issue_type="Task"
    if echo "$labels" | grep -q "bug"; then
        issue_type="Bug"
    elif echo "$labels" | grep -q "feature-request"; then
        issue_type="Story"
    elif echo "$labels" | grep -q "security"; then
        issue_type="Security"
    fi
    
    # Create JIRA ticket payload
    local jira_payload=$(cat <<EOF
{
    "fields": {
        "project": {
            "key": "${JIRA_PROJECT_KEY}"
        },
        "summary": "${title}",
        "description": {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "paragraph",
                    "content": [
                        {
                            "type": "text",
                            "text": "${body}"
                        }
                    ]
                },
                {
                    "type": "paragraph",
                    "content": [
                        {
                            "type": "text",
                            "text": "GitHub Issue: ${html_url}"
                        }
                    ]
                }
            ]
        },
        "issuetype": {
            "name": "${issue_type}"
        },
        "labels": [$(echo "$labels" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')]
    }
}
EOF
    )
    
    log "Creating JIRA ticket for GitHub issue #${issue_number}"
    local response=$(jira_api_call "issue" "POST" "$jira_payload")
    
    if echo "$response" | jq -e '.key' > /dev/null; then
        local jira_key=$(echo "$response" | jq -r '.key')
        log "Successfully created JIRA ticket: $jira_key"
        
        # Add comment to GitHub issue with JIRA link
        local github_comment=$(cat <<EOF
{
    "body": "🔗 **JIRA Integration**\\n\\nThis issue has been synchronized with JIRA ticket: [${jira_key}](${JIRA_BASE_URL}/browse/${jira_key})"
}
EOF
        )
        
        github_api_call "repos/${GITHUB_REPOSITORY}/issues/${issue_number}/comments" "POST" "$github_comment"
        echo "$jira_key"
    else
        log "Failed to create JIRA ticket: $response"
        return 1
    fi
}

# Update JIRA ticket status based on GitHub issue state
update_jira_status() {
    local jira_key="$1"
    local github_state="$2"
    
    local transition_id=""
    case "$github_state" in
        "open")
            transition_id="11"  # To Do
            ;;
        "closed")
            transition_id="31"  # Done
            ;;
    esac
    
    if [[ -n "$transition_id" ]]; then
        local transition_payload=$(cat <<EOF
{
    "transition": {
        "id": "${transition_id}"
    }
}
EOF
        )
        
        log "Updating JIRA ticket $jira_key status to $github_state"
        jira_api_call "issue/${jira_key}/transitions" "POST" "$transition_payload"
    fi
}

# Sync GitHub issues to JIRA
sync_github_to_jira() {
    log "Starting GitHub to JIRA synchronization"
    
    # Get all open GitHub issues
    local github_issues=$(github_api_call "repos/${GITHUB_REPOSITORY}/issues?state=all&per_page=100")
    
    # Process each issue
    echo "$github_issues" | jq -c '.[]' | while read -r issue; do
        local issue_number=$(echo "$issue" | jq -r '.number')
        local issue_body=$(echo "$issue" | jq -r '.body // ""')
        
        # Skip if already synchronized (check for JIRA link in comments)
        local comments=$(github_api_call "repos/${GITHUB_REPOSITORY}/issues/${issue_number}/comments")
        if echo "$comments" | jq -r '.[].body' | grep -q "JIRA Integration"; then
            log "Issue #${issue_number} already synchronized, skipping"
            continue
        fi
        
        # Create JIRA ticket
        if jira_key=$(create_jira_ticket "$issue"); then
            log "Synchronized issue #${issue_number} with JIRA ticket $jira_key"
        else
            log "Failed to synchronize issue #${issue_number}"
        fi
    done
}

# Monitor JIRA tickets for status changes
monitor_jira_tickets() {
    log "Monitoring JIRA tickets for status changes"
    
    # Search for tickets linked to GitHub
    local jql="project = ${JIRA_PROJECT_KEY} AND description ~ 'github.com'"
    local jira_issues=$(jira_api_call "search?jql=$(echo "$jql" | sed 's/ /%20/g')")
    
    echo "$jira_issues" | jq -c '.issues[]' | while read -r ticket; do
        local jira_key=$(echo "$ticket" | jq -r '.key')
        local status=$(echo "$ticket" | jq -r '.fields.status.name')
        local description=$(echo "$ticket" | jq -r '.fields.description.content[1].content[0].text // ""')
        
        # Extract GitHub issue number from description
        if [[ "$description" =~ github\.com/[^/]+/[^/]+/issues/([0-9]+) ]]; then
            local github_issue_number="${BASH_REMATCH[1]}"
            
            # Update GitHub issue based on JIRA status
            case "$status" in
                "Done"|"Closed")
                    log "Closing GitHub issue #${github_issue_number} based on JIRA status"
                    github_api_call "repos/${GITHUB_REPOSITORY}/issues/${github_issue_number}" "PATCH" '{"state": "closed"}'
                    ;;
                "In Progress")
                    # Add in-progress label
                    github_api_call "repos/${GITHUB_REPOSITORY}/issues/${github_issue_number}/labels" "POST" '["in-progress"]'
                    ;;
            esac
        fi
    done
}

# Setup JIRA webhook (requires admin privileges)
setup_jira_webhook() {
    log "Setting up JIRA webhook for GitHub integration"
    
    local webhook_url="${GITHUB_WEBHOOK_URL:-https://api.github.com/repos/${GITHUB_REPOSITORY}/dispatches}"
    
    local webhook_payload=$(cat <<EOF
{
    "name": "GitHub Integration Webhook",
    "url": "${webhook_url}",
    "events": ["jira:issue_created", "jira:issue_updated"],
    "filters": {
        "issue-related-events-section": "project = ${JIRA_PROJECT_KEY}"
    }
}
EOF
    )
    
    jira_api_call "webhook" "POST" "$webhook_payload"
}

# Generate integration report
generate_report() {
    log "Generating JIRA integration report"
    
    local report_file="${PROJECT_ROOT}/reports/jira-integration-report.md"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" <<EOF
# JIRA Integration Report
Generated: $(date)

## Synchronization Status
$(github_api_call "repos/${GITHUB_REPOSITORY}/issues?state=all" | jq '.[] | select(.body | contains("JIRA Integration")) | {number: .number, title: .title, state: .state}')

## Configuration
- JIRA Base URL: ${JIRA_BASE_URL}
- JIRA Project: ${JIRA_PROJECT_KEY}
- GitHub Repository: ${GITHUB_REPOSITORY}

## Recent Activity
$(tail -20 "$LOG_FILE")

## Next Steps
1. Review synchronized issues
2. Validate JIRA workflow mappings
3. Test bidirectional synchronization
4. Configure automated monitoring
EOF

    log "Report generated: $report_file"
}

# Main execution
main() {
    log "Starting JIRA integration script"
    
    # Check environment
    check_env_vars
    
    # Parse command line arguments
    case "${1:-sync}" in
        "sync")
            sync_github_to_jira
            ;;
        "monitor")
            monitor_jira_tickets
            ;;
        "setup-webhook")
            setup_jira_webhook
            ;;
        "report")
            generate_report
            ;;
        "help")
            cat <<EOF
JIRA Integration Script

Usage: $0 [command]

Commands:
    sync            Synchronize GitHub issues to JIRA (default)
    monitor         Monitor JIRA tickets for status changes
    setup-webhook   Setup JIRA webhook for real-time sync
    report          Generate integration status report
    help            Show this help message

Environment Variables:
    JIRA_BASE_URL      - JIRA instance URL
    JIRA_EMAIL         - JIRA user email
    JIRA_API_TOKEN     - JIRA API token
    JIRA_PROJECT_KEY   - JIRA project key
    GITHUB_TOKEN       - GitHub API token
    GITHUB_REPOSITORY  - GitHub repository (owner/repo)
    GITHUB_WEBHOOK_URL - GitHub webhook URL (optional)
EOF
            ;;
        *)
            error_exit "Unknown command: $1. Use 'help' for usage information."
            ;;
    esac
    
    log "JIRA integration script completed"
}

# Execute main function with all arguments
main "$@"

