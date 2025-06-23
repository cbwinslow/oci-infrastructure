#!/bin/bash

# =============================================================================
# Logging and Reporting Utility
# =============================================================================
# This script provides logging functions and status reporting capabilities
# for infrastructure management operations.
#
# Author: cbwinslow
# Date: $(date +%Y-%m-%d)
# =============================================================================

# Configuration
# Source configuration file if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/logging_config.sh" && -z "${LOG_DIR:-}" ]]; then
    source "${SCRIPT_DIR}/logging_config.sh"
fi

# Fallback configuration if not set by config file
LOG_DIR="${LOG_DIR:-${HOME}/CBW_SHARED_STORAGE/oci-infrastructure/logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/infrastructure.log}"
STATUS_FILE="${STATUS_FILE:-${LOG_DIR}/status.json}"
REPORT_FILE="${REPORT_FILE:-${LOG_DIR}/status_report.txt}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Initialize status tracking file if it doesn't exist
if [[ ! -f "$STATUS_FILE" ]]; then
    cat > "$STATUS_FILE" << 'EOF'
{
  "session_id": "",
  "start_time": "",
  "last_update": "",
  "changes_made": [],
  "permissions_fixed": [],
  "commits_created": [],
  "sync_status": {
    "git_status": "unknown",
    "last_sync": "",
    "uncommitted_changes": 0,
    "unpushed_commits": 0
  },
  "operations": [],
  "errors": []
}
EOF
fi

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Log info messages
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" | tee -a "$LOG_FILE"
    
    # Update status file with operation
    update_status_operation "INFO" "$message"
}

# Log error messages
log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE" >&2
    
    # Update status file with error
    update_status_error "$message"
}

# Log warning messages
log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [WARNING] $message" | tee -a "$LOG_FILE"
    
    # Update status file with operation
    update_status_operation "WARNING" "$message"
}

# Log debug messages (only if DEBUG is set)
log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        local message="$1"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [DEBUG] $message" | tee -a "$LOG_FILE"
    fi
}

# =============================================================================
# STATUS TRACKING FUNCTIONS
# =============================================================================

# Initialize a new session
init_session() {
    local session_id=$(date +%s)_$$
    local current_time=$(date -Iseconds)
    
    # Update status file with session info
    jq --arg sid "$session_id" --arg time "$current_time" '
        .session_id = $sid |
        .start_time = $time |
        .last_update = $time
    ' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
    
    log_info "Started new session: $session_id"
}

# Update status with operation
update_status_operation() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    
    jq --arg level "$level" --arg msg "$message" --arg time "$timestamp" '
        .last_update = $time |
        .operations += [{"level": $level, "message": $msg, "timestamp": $time}]
    ' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Update status with error
update_status_error() {
    local message="$1"
    local timestamp=$(date -Iseconds)
    
    jq --arg msg "$message" --arg time "$timestamp" '
        .last_update = $time |
        .errors += [{"message": $msg, "timestamp": $time}]
    ' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Log a change made
log_change() {
    local change_type="$1"
    local description="$2"
    local file_path="${3:-}"
    local timestamp=$(date -Iseconds)
    
    log_info "Change made: $change_type - $description"
    
    jq --arg type "$change_type" --arg desc "$description" --arg path "$file_path" --arg time "$timestamp" '
        .last_update = $time |
        .changes_made += [{"type": $type, "description": $desc, "file_path": $path, "timestamp": $time}]
    ' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Log a permission fix
log_permission_fix() {
    local target="$1"
    local old_perms="$2"
    local new_perms="$3"
    local timestamp=$(date -Iseconds)
    
    log_info "Permission fixed: $target ($old_perms -> $new_perms)"
    
    jq --arg target "$target" --arg old "$old_perms" --arg new "$new_perms" --arg time "$timestamp" '
        .last_update = $time |
        .permissions_fixed += [{"target": $target, "old_permissions": $old, "new_permissions": $new, "timestamp": $time}]
    ' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Log a commit created
log_commit() {
    local commit_hash="$1"
    local commit_message="$2"
    local files_changed="${3:-0}"
    local timestamp=$(date -Iseconds)
    
    log_info "Commit created: $commit_hash - $commit_message"
    
    jq --arg hash "$commit_hash" --arg msg "$commit_message" --arg files "$files_changed" --arg time "$timestamp" '
        .last_update = $time |
        .commits_created += [{"hash": $hash, "message": $msg, "files_changed": ($files | tonumber), "timestamp": $time}]
    ' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Update sync status
update_sync_status() {
    local git_status="$1"
    local uncommitted_changes="${2:-0}"
    local unpushed_commits="${3:-0}"
    local timestamp=$(date -Iseconds)
    
    log_info "Sync status updated: $git_status"
    
    jq --arg status "$git_status" --arg uncommitted "$uncommitted_changes" --arg unpushed "$unpushed_commits" --arg time "$timestamp" '
        .last_update = $time |
        .sync_status.git_status = $status |
        .sync_status.last_sync = $time |
        .sync_status.uncommitted_changes = ($uncommitted | tonumber) |
        .sync_status.unpushed_commits = ($unpushed | tonumber)
    ' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# =============================================================================
# REPORTING FUNCTIONS
# =============================================================================

# Generate comprehensive status report
generate_status_report() {
    local report_format="${1:-text}"
    
    log_info "Generating status report in $report_format format"
    
    if [[ "$report_format" == "json" ]]; then
        generate_json_report
    else
        generate_text_report
    fi
}

# Generate text status report
generate_text_report() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "$REPORT_FILE" << EOF
=============================================================================
INFRASTRUCTURE STATUS REPORT
=============================================================================
Generated: $current_time
Session ID: $(jq -r '.session_id' "$STATUS_FILE")
Started: $(jq -r '.start_time' "$STATUS_FILE")
Last Update: $(jq -r '.last_update' "$STATUS_FILE")

=============================================================================
SUMMARY
=============================================================================
Changes Made: $(jq '.changes_made | length' "$STATUS_FILE")
Permissions Fixed: $(jq '.permissions_fixed | length' "$STATUS_FILE")
Commits Created: $(jq '.commits_created | length' "$STATUS_FILE")
Total Operations: $(jq '.operations | length' "$STATUS_FILE")
Errors Encountered: $(jq '.errors | length' "$STATUS_FILE")

=============================================================================
SYNC STATUS
=============================================================================
Git Status: $(jq -r '.sync_status.git_status' "$STATUS_FILE")
Last Sync: $(jq -r '.sync_status.last_sync' "$STATUS_FILE")
Uncommitted Changes: $(jq -r '.sync_status.uncommitted_changes' "$STATUS_FILE")
Unpushed Commits: $(jq -r '.sync_status.unpushed_commits' "$STATUS_FILE")

=============================================================================
CHANGES MADE
=============================================================================
EOF

    if [[ $(jq '.changes_made | length' "$STATUS_FILE") -gt 0 ]]; then
        jq -r '.changes_made[] | "[\(.timestamp)] \(.type): \(.description) (\(.file_path // "N/A"))"' "$STATUS_FILE" >> "$REPORT_FILE"
    else
        echo "No changes recorded." >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

=============================================================================
PERMISSIONS FIXED
=============================================================================
EOF

    if [[ $(jq '.permissions_fixed | length' "$STATUS_FILE") -gt 0 ]]; then
        jq -r '.permissions_fixed[] | "[\(.timestamp)] \(.target): \(.old_permissions) -> \(.new_permissions)"' "$STATUS_FILE" >> "$REPORT_FILE"
    else
        echo "No permission fixes recorded." >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

=============================================================================
COMMITS CREATED
=============================================================================
EOF

    if [[ $(jq '.commits_created | length' "$STATUS_FILE") -gt 0 ]]; then
        jq -r '.commits_created[] | "[\(.timestamp)] \(.hash): \(.message) (\(.files_changed) files)"' "$STATUS_FILE" >> "$REPORT_FILE"
    else
        echo "No commits recorded." >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

=============================================================================
RECENT OPERATIONS
=============================================================================
EOF

    if [[ $(jq '.operations | length' "$STATUS_FILE") -gt 0 ]]; then
        jq -r '.operations | reverse | .[0:10][] | "[\(.timestamp)] [\(.level)] \(.message)"' "$STATUS_FILE" >> "$REPORT_FILE"
    else
        echo "No operations recorded." >> "$REPORT_FILE"
    fi

    if [[ $(jq '.errors | length' "$STATUS_FILE") -gt 0 ]]; then
        cat >> "$REPORT_FILE" << EOF

=============================================================================
ERRORS
=============================================================================
EOF
        jq -r '.errors[] | "[\(.timestamp)] \(.message)"' "$STATUS_FILE" >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo "==============================================================================" >> "$REPORT_FILE"
    
    # Display the report
    cat "$REPORT_FILE"
    
    log_info "Status report generated: $REPORT_FILE"
}

# Generate JSON status report
generate_json_report() {
    local json_report_file="${REPORT_FILE%.txt}.json"
    
    jq --arg generated "$(date -Iseconds)" '. + {"report_generated": $generated}' "$STATUS_FILE" > "$json_report_file"
    
    log_info "JSON status report generated: $json_report_file"
    echo "JSON report saved to: $json_report_file"
}

# Check current git sync status
check_git_sync_status() {
    if [[ ! -d .git ]]; then
        update_sync_status "not_a_git_repo" 0 0
        return 1
    fi
    
    local uncommitted_changes=$(git status --porcelain | wc -l)
    local unpushed_commits=0
    
    # Check for unpushed commits (only if we have a remote)
    if git remote | grep -q .; then
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        if [[ "$current_branch" != "unknown" ]]; then
            unpushed_commits=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
        fi
    fi
    
    local git_status="clean"
    if [[ $uncommitted_changes -gt 0 ]]; then
        git_status="uncommitted_changes"
    elif [[ $unpushed_commits -gt 0 ]]; then
        git_status="unpushed_commits"
    fi
    
    update_sync_status "$git_status" "$uncommitted_changes" "$unpushed_commits"
    
    log_info "Git sync status checked: $git_status ($uncommitted_changes uncommitted, $unpushed_commits unpushed)"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Show current status
show_status() {
    echo "=== Current Status ==="
    echo "Session ID: $(jq -r '.session_id' "$STATUS_FILE")"
    echo "Changes Made: $(jq '.changes_made | length' "$STATUS_FILE")"
    echo "Permissions Fixed: $(jq '.permissions_fixed | length' "$STATUS_FILE")"
    echo "Commits Created: $(jq '.commits_created | length' "$STATUS_FILE")"
    echo "Git Status: $(jq -r '.sync_status.git_status' "$STATUS_FILE")"
    echo "Last Update: $(jq -r '.last_update' "$STATUS_FILE")"
}

# Clean up old logs (keep last 30 days)
cleanup_logs() {
    log_info "Cleaning up old logs"
    find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find "$LOG_DIR" -name "*.json" -mtime +30 -delete 2>/dev/null || true
    find "$LOG_DIR" -name "*.txt" -mtime +30 -delete 2>/dev/null || true
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    case "${1:-}" in
        "init")
            init_session
            ;;
        "status")
            show_status
            ;;
        "report")
            generate_status_report "${2:-text}"
            ;;
        "check-git")
            check_git_sync_status
            ;;
        "cleanup")
            cleanup_logs
            ;;
        "test")
            # Test the logging functions
            init_session
            log_info "Testing logging functions"
            log_change "file_modification" "Updated terraform configuration" "/path/to/main.tf"
            log_permission_fix "/path/to/script.sh" "644" "755"
            log_commit "abc123def" "Add logging and reporting functionality" "3"
            check_git_sync_status
            generate_status_report
            ;;
        *)
            echo "Usage: $0 {init|status|report|check-git|cleanup|test}"
            echo ""
            echo "Commands:"
            echo "  init        - Initialize a new logging session"
            echo "  status      - Show current status summary"
            echo "  report      - Generate comprehensive status report"
            echo "  check-git   - Check and update git sync status"
            echo "  cleanup     - Clean up old log files"
            echo "  test        - Run test of logging functions"
            echo ""
            echo "Environment Variables:"
            echo "  LOG_DIR     - Directory for log files (default: /var/log/oci-infrastructure)"
            echo "  LOG_FILE    - Main log file path"
            echo "  DEBUG       - Set to 'true' to enable debug logging"
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

