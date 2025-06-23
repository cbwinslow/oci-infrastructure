#!/bin/bash

# =============================================================================
# Example Script with Integrated Logging
# =============================================================================
# This script demonstrates how to integrate the logging and reporting functions
# into your infrastructure management scripts.
# =============================================================================

# Source the logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_and_reporting.sh"

# Initialize logging session
init_session

# Example infrastructure management operations
perform_infrastructure_operations() {
    log_info "Starting infrastructure operations"
    
    # Example: File modification
    log_info "Updating Terraform configuration files"
    
    # Simulate making changes to a file
    local config_file="/tmp/example_main.tf"
    echo "# Updated configuration $(date)" > "$config_file"
    log_change "file_modification" "Updated main Terraform configuration" "$config_file"
    
    # Example: Permission fix
    log_info "Fixing script permissions"
    chmod 755 "$0"
    log_permission_fix "$0" "644" "755"
    
    # Example: Simulating git operations
    if [[ -d .git ]]; then
        log_info "Committing changes to git"
        
        # Check if there are any changes to commit
        if [[ -n "$(git status --porcelain)" ]]; then
            git add .
            local commit_hash=$(git rev-parse --short HEAD)
            git commit -m "Add logging and reporting functionality" --quiet
            local new_commit_hash=$(git rev-parse --short HEAD)
            local files_changed=$(git diff-tree --no-commit-id --name-only -r HEAD | wc -l)
            
            log_commit "$new_commit_hash" "Add logging and reporting functionality" "$files_changed"
        else
            log_info "No changes to commit"
        fi
    else
        log_warning "Not in a git repository - skipping commit operations"
    fi
    
    # Update sync status
    check_git_sync_status
    
    log_info "Infrastructure operations completed"
}

# Error handling example
handle_error_example() {
    log_info "Demonstrating error handling"
    
    # Simulate an error condition
    if ! command -v non_existent_command >/dev/null 2>&1; then
        log_error "Required command 'non_existent_command' not found"
        return 1
    fi
}

# Main execution
main() {
    case "${1:-run}" in
        "run")
            log_info "Starting example infrastructure script"
            
            perform_infrastructure_operations
            
            # Demonstrate error handling
            handle_error_example || log_warning "Error handling example completed with expected error"
            
            log_info "Example script completed successfully"
            
            # Generate status report
            echo ""
            echo "Generating status report..."
            generate_status_report
            ;;
        "status")
            show_status
            ;;
        "report")
            generate_status_report "${2:-text}"
            ;;
        *)
            echo "Usage: $0 {run|status|report}"
            echo ""
            echo "This is an example script demonstrating logging integration."
            echo ""
            echo "Commands:"
            echo "  run     - Run the example operations with logging"
            echo "  status  - Show current logging status"
            echo "  report  - Generate status report"
            ;;
    esac
}

# Execute main function
main "$@"

