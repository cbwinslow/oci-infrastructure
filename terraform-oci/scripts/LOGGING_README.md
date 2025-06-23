# Logging and Reporting System

This documentation describes the comprehensive logging and reporting system implemented for infrastructure management operations.

## Overview

The logging system provides:
- **Structured logging functions** (`log_info`, `log_error`, `log_warning`, `log_debug`)
- **Activity tracking** (changes, permissions, commits, sync status)
- **Comprehensive status reports** (text and JSON formats)
- **Session management** for tracking operations over time

## Quick Start

### 1. Source the logging functions in your script:

```bash
#!/bin/bash

# Source the logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_and_reporting.sh"

# Initialize a new session
init_session
```

### 2. Use the basic logging functions:

```bash
# Basic logging functions as requested
log_info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

# Example usage:
log_info "Starting deployment process"
log_error "Failed to connect to database"
```

### 3. Track specific activities:

```bash
# Log changes made
log_change "file_modification" "Updated main.tf configuration" "/path/to/main.tf"

# Log permission fixes
log_permission_fix "/path/to/script.sh" "644" "755"

# Log commits created
log_commit "abc123def" "Add new infrastructure components" "5"

# Update sync status
check_git_sync_status
```

### 4. Generate status reports:

```bash
# Generate text report
generate_status_report

# Generate JSON report
generate_status_report json
```

## Available Functions

### Basic Logging Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `log_info()` | Log informational messages | `log_info "Process started"` |
| `log_error()` | Log error messages | `log_error "Connection failed"` |
| `log_warning()` | Log warning messages | `log_warning "Deprecated option used"` |
| `log_debug()` | Log debug messages (only if DEBUG=true) | `log_debug "Variable value: $var"` |

### Activity Tracking Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `log_change()` | Track changes made to files/configs | `log_change "type" "description" "/path"` |
| `log_permission_fix()` | Track permission changes | `log_permission_fix "/path" "644" "755"` |
| `log_commit()` | Track git commits created | `log_commit "hash" "message" "file_count"` |
| `check_git_sync_status()` | Check and update git sync status | `check_git_sync_status` |

### Session Management

| Function | Description | Usage |
|----------|-------------|-------|
| `init_session()` | Start a new logging session | `init_session` |
| `show_status()` | Display current session status | `show_status` |

### Reporting Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `generate_status_report()` | Generate comprehensive report | `generate_status_report [text\|json]` |
| `cleanup_logs()` | Clean up old log files (30+ days) | `cleanup_logs` |

## Status Report Contents

The status reports include:

### 1. Changes Made
- Type of change (file_modification, configuration_update, etc.)
- Description of what was changed
- File path (if applicable)
- Timestamp

### 2. Permissions Fixed
- Target file/directory
- Old permissions → New permissions
- Timestamp

### 3. Commits Created
- Commit hash
- Commit message
- Number of files changed
- Timestamp

### 4. Sync Status
- Git repository status (clean, uncommitted_changes, unpushed_commits)
- Number of uncommitted changes
- Number of unpushed commits
- Last sync timestamp

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_DIR` | `$HOME/CBW_SHARED_STORAGE/oci-infrastructure/logs` | Directory for log files |
| `LOG_FILE` | `$LOG_DIR/infrastructure.log` | Main log file |
| `STATUS_FILE` | `$LOG_DIR/status.json` | JSON status tracking file |
| `REPORT_FILE` | `$LOG_DIR/status_report.txt` | Text report file |
| `DEBUG` | `false` | Enable debug logging |

### Configuration File

The system automatically loads configuration from `logging_config.sh` if available:

```bash
# Source configuration
source "./logging_config.sh"
```

## Command Line Usage

The main script can be used directly from the command line:

```bash
# Initialize a new session
./logging_and_reporting.sh init

# Show current status
./logging_and_reporting.sh status

# Generate status report
./logging_and_reporting.sh report [text|json]

# Check git sync status
./logging_and_reporting.sh check-git

# Clean up old logs
./logging_and_reporting.sh cleanup

# Run test
./logging_and_reporting.sh test
```

## Integration Example

See `example_with_logging.sh` for a complete example of how to integrate the logging functions into your infrastructure scripts.

```bash
#!/bin/bash

# Source the logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_and_reporting.sh"

# Initialize logging session
init_session

# Your infrastructure operations here
log_info "Starting infrastructure deployment"

# Example operations
terraform plan > plan.out
log_change "infrastructure_plan" "Generated Terraform plan" "plan.out"

terraform apply -auto-approve
log_change "infrastructure_apply" "Applied Terraform changes" ""

# Check git status and commit if needed
if [[ -n "$(git status --porcelain)" ]]; then
    git add .
    git commit -m "Update infrastructure configuration"
    commit_hash=$(git rev-parse --short HEAD)
    files_changed=$(git diff-tree --no-commit-id --name-only -r HEAD | wc -l)
    log_commit "$commit_hash" "Update infrastructure configuration" "$files_changed"
fi

# Update sync status
check_git_sync_status

# Generate final report
generate_status_report

log_info "Infrastructure deployment completed"
```

## File Structure

```
terraform-oci/scripts/
├── logging_and_reporting.sh     # Main logging utility
├── logging_config.sh            # Configuration file
├── example_with_logging.sh      # Integration example
└── LOGGING_README.md           # This documentation
```

## Log Files

All log files are stored in the configured log directory:

```
logs/
├── infrastructure.log           # Main log file
├── status.json                 # JSON status tracking
├── status_report.txt           # Latest text report
└── status_report.json          # Latest JSON report
```

## Improvements Available

As per the requirement to suggest 3 improvements for any script:

### 1. **Remote Logging Integration**
- Add support for sending logs to centralized logging systems (ELK, Splunk, CloudWatch)
- Implement log forwarding with structured JSON format
- Add log level filtering and sampling for high-volume environments

### 2. **Advanced Alerting and Notifications**
- Integrate with notification systems (Slack, email, PagerDuty)
- Add threshold-based alerting (e.g., alert after X errors)
- Implement smart notifications for critical infrastructure changes

### 3. **Enhanced Reporting and Analytics**
- Add trend analysis and historical reporting
- Implement dashboard generation with charts and graphs
- Add performance metrics tracking (execution time, resource usage)
- Create automated report scheduling and distribution

These improvements would make the logging system suitable for enterprise-scale infrastructure management with enhanced observability and operational insights.

