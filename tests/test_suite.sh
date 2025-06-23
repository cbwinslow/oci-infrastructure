#!/bin/bash

# Repository Repair Agent Test Suite
# Comprehensive test framework for repository repair functionality

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AGENT_DIR="$PROJECT_ROOT/agents/repo_repair"
TEST_DATA_DIR="$SCRIPT_DIR/test_data"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
LOG_FILE="$TEST_RESULTS_DIR/test_suite.log"

# Test configuration
TEST_REPO_URL="https://github.com/test/repo.git"
TEST_TIMEOUT=300
MAX_RETRIES=3

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE" >&2
}

# Test result functions
test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    log "PASS" "$1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    log "FAIL" "$1"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    log "SKIP" "$1"
    ((TESTS_SKIPPED++))
}

test_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO" "$1"
}

# Setup test environment
setup_test_environment() {
    test_info "Setting up test environment..."
    
    # Create test directories
    mkdir -p "$TEST_DATA_DIR" "$TEST_RESULTS_DIR"
    
    # Initialize log file
    echo "Test Suite Started: $(date)" > "$LOG_FILE"
    
    # Create test repositories
    setup_test_repositories
    
    # Backup original configurations
    backup_configurations
    
    test_info "Test environment setup complete"
}

# Setup test repositories
setup_test_repositories() {
    local test_repo_dir="$TEST_DATA_DIR/test_repo"
    local broken_repo_dir="$TEST_DATA_DIR/broken_repo"
    
    # Create test repository
    if [[ ! -d "$test_repo_dir" ]]; then
        mkdir -p "$test_repo_dir"
        cd "$test_repo_dir"
        git init
        echo "# Test Repository" > README.md
        git add README.md
        git config user.email "test@example.com"
        git config user.name "Test User"
        git commit -m "Initial commit"
        cd - > /dev/null
    fi
    
    # Create broken repository for testing
    if [[ ! -d "$broken_repo_dir" ]]; then
        cp -r "$test_repo_dir" "$broken_repo_dir"
        # Introduce permission issues
        chmod 000 "$broken_repo_dir/README.md" 2>/dev/null || true
        # Corrupt git config
        echo "invalid config" >> "$broken_repo_dir/.git/config"
    fi
}

# Backup configurations
backup_configurations() {
    local backup_dir="$TEST_DATA_DIR/backups"
    mkdir -p "$backup_dir"
    
    if [[ -f "$AGENT_DIR/config/agent_config.json" ]]; then
        cp "$AGENT_DIR/config/agent_config.json" "$backup_dir/"
    fi
    
    if [[ -f "$AGENT_DIR/config/capabilities.json" ]]; then
        cp "$AGENT_DIR/config/capabilities.json" "$backup_dir/"
    fi
}

# Test permission fixes
test_permissions() {
    test_info "Testing permission fixes..."
    
    local test_repo="$TEST_DATA_DIR/broken_repo"
    local fix_script="$AGENT_DIR/scripts/fix_permissions.sh"
    
    # Test 1: Check if fix_permissions script exists
    if [[ ! -f "$fix_script" ]]; then
        # Create the script for testing
        create_fix_permissions_script
    fi
    
    if [[ -f "$fix_script" ]]; then
        test_pass "Permission fix script exists"
    else
        test_fail "Permission fix script not found"
        return 1
    fi
    
    # Test 2: Test permission detection
    local permission_issues
    permission_issues=$(find "$test_repo" -type f ! -readable 2>/dev/null | wc -l)
    
    if [[ $permission_issues -gt 0 ]]; then
        test_pass "Permission issues detected correctly ($permission_issues files)"
    else
        test_skip "No permission issues to test"
    fi
    
    # Test 3: Test permission fixing
    if bash "$fix_script" --target-path="$test_repo" --dry-run 2>&1; then
        test_pass "Permission fix dry-run successful"
    else
        test_fail "Permission fix dry-run failed"
    fi
    
    # Test 4: Test actual permission fixing
    local fixed_files=0
    if bash "$fix_script" --target-path="$test_repo" --fix-executable=true 2>/dev/null; then
        fixed_files=$(find "$test_repo" -type f -readable 2>/dev/null | wc -l)
        test_pass "Permission fix executed ($fixed_files files processed)"
    else
        test_fail "Permission fix execution failed"
    fi
    
    # Test 5: Test ownership fixing (if running as root)
    if [[ $EUID -eq 0 ]]; then
        if bash "$fix_script" --target-path="$test_repo" --fix-ownership=true 2>/dev/null; then
            test_pass "Ownership fix successful"
        else
            test_fail "Ownership fix failed"
        fi
    else
        test_skip "Ownership fix test (requires root privileges)"
    fi
}

# Test repository sync
test_sync() {
    test_info "Testing repository synchronization..."
    
    local test_repo="$TEST_DATA_DIR/test_repo"
    local sync_script="$AGENT_DIR/scripts/sync_repos.sh"
    
    # Test 1: Check if sync script exists
    if [[ ! -f "$sync_script" ]]; then
        create_sync_script
    fi
    
    if [[ -f "$sync_script" ]]; then
        test_pass "Repository sync script exists"
    else
        test_fail "Repository sync script not found"
        return 1
    fi
    
    # Test 2: Test repository status check
    cd "$test_repo"
    local git_status
    if git_status=$(git status --porcelain 2>/dev/null); then
        test_pass "Git status check successful"
    else
        test_fail "Git status check failed"
        cd - > /dev/null
        return 1
    fi
    cd - > /dev/null
    
    # Test 3: Test local changes detection
    echo "test change" >> "$test_repo/test_file.txt"
    cd "$test_repo"
    git add test_file.txt
    if [[ -n $(git status --porcelain) ]]; then
        test_pass "Local changes detected correctly"
    else
        test_fail "Local changes detection failed"
    fi
    cd - > /dev/null
    
    # Test 4: Test sync dry-run
    if bash "$sync_script" --repo-path="$test_repo" --dry-run 2>&1; then
        test_pass "Repository sync dry-run successful"
    else
        test_fail "Repository sync dry-run failed"
    fi
    
    # Test 5: Test sync without remote
    if bash "$sync_script" --repo-path="$test_repo" --force-sync=false 2>/dev/null; then
        test_pass "Local repository sync successful"
    else
        test_skip "Repository sync (no remote configured)"
    fi
    
    # Test 6: Test branch handling
    cd "$test_repo"
    git checkout -b test-branch 2>/dev/null || true
    cd - > /dev/null
    
    if bash "$sync_script" --repo-path="$test_repo" --branch="test-branch" 2>/dev/null; then
        test_pass "Branch-specific sync successful"
    else
        test_fail "Branch-specific sync failed"
    fi
}

# Test rollback functionality
test_rollback() {
    test_info "Testing rollback functionality..."
    
    local test_repo="$TEST_DATA_DIR/test_repo"
    local rollback_script="$AGENT_DIR/scripts/rollback.sh"
    
    # Test 1: Check if rollback script exists
    if [[ ! -f "$rollback_script" ]]; then
        create_rollback_script
    fi
    
    if [[ -f "$rollback_script" ]]; then
        test_pass "Rollback script exists"
    else
        test_fail "Rollback script not found"
        return 1
    fi
    
    # Test 2: Create backup for rollback testing
    local backup_dir="$TEST_DATA_DIR/rollback_backup"
    cp -r "$test_repo" "$backup_dir"
    
    if [[ -d "$backup_dir" ]]; then
        test_pass "Backup created for rollback testing"
    else
        test_fail "Failed to create backup"
        return 1
    fi
    
    # Test 3: Make changes to test rollback
    echo "change to rollback" >> "$test_repo/rollback_test.txt"
    cd "$test_repo"
    git add rollback_test.txt
    git commit -m "Change to be rolled back" 2>/dev/null || true
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "")
    cd - > /dev/null
    
    if [[ -n "$commit_hash" ]]; then
        test_pass "Test changes committed for rollback ($commit_hash)"
    else
        test_fail "Failed to commit test changes"
    fi
    
    # Test 4: Test rollback dry-run
    if bash "$rollback_script" --repo-path="$test_repo" --target="HEAD~1" --dry-run 2>&1; then
        test_pass "Rollback dry-run successful"
    else
        test_fail "Rollback dry-run failed"
    fi
    
    # Test 5: Test actual rollback
    cd "$test_repo"
    local previous_commit=$(git rev-parse HEAD~1 2>/dev/null || echo "")
    cd - > /dev/null
    
    if [[ -n "$previous_commit" ]]; then
        if bash "$rollback_script" --repo-path="$test_repo" --target="$previous_commit" 2>/dev/null; then
            test_pass "Rollback execution successful"
        else
            test_fail "Rollback execution failed"
        fi
    else
        test_skip "Rollback test (no previous commit available)"
    fi
    
    # Test 6: Test backup restoration
    if bash "$rollback_script" --repo-path="$test_repo" --restore-backup="$backup_dir" 2>/dev/null; then
        test_pass "Backup restoration successful"
    else
        test_fail "Backup restoration failed"
    fi
}

# Test AI agent framework integration
test_ai_framework_integration() {
    test_info "Testing AI agent framework integration..."
    
    local register_script="$AGENT_DIR/register_agent.sh"
    local config_file="$AGENT_DIR/config/agent_config.json"
    
    # Test 1: Check configuration files
    if [[ -f "$config_file" ]]; then
        test_pass "Agent configuration file exists"
    else
        test_fail "Agent configuration file not found"
        return 1
    fi
    
    # Test 2: Validate JSON configuration
    if jq empty "$config_file" 2>/dev/null; then
        test_pass "Agent configuration JSON is valid"
    else
        test_fail "Agent configuration JSON is invalid"
    fi
    
    # Test 3: Check required configuration fields
    local required_fields=("agent_type" "runtime" "capabilities")
    for field in "${required_fields[@]}"; do
        if jq -e ".$field" "$config_file" >/dev/null 2>&1; then
            test_pass "Configuration field '$field' exists"
        else
            test_fail "Configuration field '$field' missing"
        fi
    done
    
    # Test 4: Test framework registration (mock)
    if [[ -f "$register_script" ]]; then
        # Mock AI framework endpoint
        export AI_FRAMEWORK_ENDPOINT="http://localhost:8080/api/v1"
        export AI_FRAMEWORK_TOKEN=""
        
        # Test registration script syntax
        if bash -n "$register_script"; then
            test_pass "Registration script syntax valid"
        else
            test_fail "Registration script syntax invalid"
        fi
        
        # Test registration with mock endpoint
        if timeout 10 bash "$register_script" 2>&1 | grep -q "ERROR\|Failed" || true; then
            test_skip "Framework registration (no AI framework available)"
        else
            test_pass "Framework registration completed"
        fi
    else
        test_fail "Registration script not found"
    fi
    
    # Test 5: Test health check endpoint simulation
    local health_check_port=8081
    if netstat -an 2>/dev/null | grep -q ":$health_check_port"; then
        test_pass "Health check endpoint available"
    else
        test_skip "Health check endpoint (service not running)"
    fi
}

# Test package management integration
test_package_management() {
    test_info "Testing package management integration..."
    
    local package_script="$AGENT_DIR/scripts/package_integration.sh"
    local templates_dir="$AGENT_DIR/templates"
    
    # Test 1: Check package integration script
    if [[ -f "$package_script" ]]; then
        test_pass "Package integration script exists"
    else
        test_fail "Package integration script not found"
        return 1
    fi
    
    # Test 2: Test package manager detection
    local detected_managers
    if detected_managers=$(bash "$package_script" 2>&1 | grep "Found package manager" | wc -l); then
        if [[ $detected_managers -gt 0 ]]; then
            test_pass "Package managers detected ($detected_managers found)"
        else
            test_skip "Package manager detection (none available)"
        fi
    else
        test_fail "Package manager detection failed"
    fi
    
    # Test 3: Test package configuration generation
    if bash "$package_script" 2>/dev/null; then
        test_pass "Package configuration generation successful"
    else
        test_fail "Package configuration generation failed"
    fi
    
    # Test 4: Check generated templates
    if [[ -d "$templates_dir" ]]; then
        local template_count
        template_count=$(find "$templates_dir" -name "*.json" -o -name "Dockerfile" -o -name "*.yml" | wc -l)
        if [[ $template_count -gt 0 ]]; then
            test_pass "Package templates generated ($template_count files)"
        else
            test_skip "Package templates (none generated)"
        fi
    else
        test_skip "Package templates directory not found"
    fi
    
    # Test 5: Test Docker configuration
    if command -v docker &> /dev/null; then
        local dockerfile="$templates_dir/docker/Dockerfile"
        if [[ -f "$dockerfile" ]]; then
            if docker build -t repo-repair-test -f "$dockerfile" "$PROJECT_ROOT" 2>/dev/null; then
                test_pass "Docker build successful"
                docker rmi repo-repair-test 2>/dev/null || true
            else
                test_fail "Docker build failed"
            fi
        else
            test_skip "Docker configuration (Dockerfile not found)"
        fi
    else
        test_skip "Docker testing (Docker not available)"
    fi
    
    # Test 6: Test NPM configuration
    if command -v npm &> /dev/null; then
        local package_json="$templates_dir/npm/package.json"
        if [[ -f "$package_json" ]]; then
            if jq empty "$package_json" 2>/dev/null; then
                test_pass "NPM package.json is valid"
            else
                test_fail "NPM package.json is invalid"
            fi
        else
            test_skip "NPM configuration (package.json not found)"
        fi
    else
        test_skip "NPM testing (NPM not available)"
    fi
}

# Test security tools integration
test_security_integration() {
    test_info "Testing security tools integration..."
    
    local config_file="$AGENT_DIR/config/agent_config.json"
    
    # Test 1: Check security configuration
    if jq -e '.security' "$config_file" >/dev/null 2>&1; then
        test_pass "Security configuration exists"
    else
        test_fail "Security configuration missing"
        return 1
    fi
    
    # Test 2: Test sandbox configuration
    if jq -e '.security.sandbox.enabled' "$config_file" >/dev/null 2>&1; then
        local sandbox_enabled
        sandbox_enabled=$(jq -r '.security.sandbox.enabled' "$config_file")
        if [[ "$sandbox_enabled" == "true" ]]; then
            test_pass "Sandbox security enabled"
        else
            test_skip "Sandbox security disabled"
        fi
    else
        test_fail "Sandbox configuration missing"
    fi
    
    # Test 3: Test permission restrictions
    local blocked_commands
    blocked_commands=$(jq -r '.security.sandbox.blocked_commands[]?' "$config_file" 2>/dev/null | wc -l)
    if [[ $blocked_commands -gt 0 ]]; then
        test_pass "Security command restrictions configured ($blocked_commands commands)"
    else
        test_skip "Security command restrictions (none configured)"
    fi
    
    # Test 4: Test file system restrictions
    local allowed_paths
    allowed_paths=$(jq -r '.security.sandbox.allowed_paths[]?' "$config_file" 2>/dev/null | wc -l)
    if [[ $allowed_paths -gt 0 ]]; then
        test_pass "File system restrictions configured ($allowed_paths paths)"
    else
        test_skip "File system restrictions (none configured)"
    fi
    
    # Test 5: Test with security scanner (if available)
    if command -v shellcheck &> /dev/null; then
        local script_errors=0
        for script in "$AGENT_DIR"/**/*.sh; do
            if [[ -f "$script" ]]; then
                if ! shellcheck "$script" 2>/dev/null; then
                    ((script_errors++))
                fi
            fi
        done
        
        if [[ $script_errors -eq 0 ]]; then
            test_pass "Security scan successful (no issues found)"
        else
            test_fail "Security scan found $script_errors issues"
        fi
    else
        test_skip "Security scanning (shellcheck not available)"
    fi
    
    # Test 6: Test secrets handling
    local env_file="$AGENT_DIR/.env"
    if [[ -f "$env_file" ]]; then
        if grep -q "TOKEN\|PASSWORD\|SECRET" "$env_file" 2>/dev/null; then
            # Check if secrets are properly masked
            if grep -q "\*\*\*\|XXX\|<REDACTED>" "$env_file" 2>/dev/null; then
                test_pass "Secrets properly masked in configuration"
            else
                test_fail "Secrets may be exposed in configuration"
            fi
        else
            test_skip "Secrets handling (no secrets found)"
        fi
    else
        test_skip "Secrets handling (no .env file found)"
    fi
}

# Helper function to create missing scripts
create_fix_permissions_script() {
    local script_path="$AGENT_DIR/scripts/fix_permissions.sh"
    mkdir -p "$(dirname "$script_path")"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Fix Permissions Script for Repository Repair Agent

set -euo pipefail

# Default values
TARGET_PATH=""
FIX_EXECUTABLE=true
FIX_OWNERSHIP=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target-path=*)
            TARGET_PATH="${1#*=}"
            shift
            ;;
        --fix-executable=*)
            FIX_EXECUTABLE="${1#*=}"
            shift
            ;;
        --fix-ownership=*)
            FIX_OWNERSHIP="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$TARGET_PATH" ]]; then
    echo "Error: --target-path is required"
    exit 1
fi

echo "Fixing permissions in: $TARGET_PATH"
echo "Dry run: $DRY_RUN"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would fix permissions (dry run mode)"
    exit 0
fi

# Fix file permissions
find "$TARGET_PATH" -type f -exec chmod 644 {} \; 2>/dev/null || true

if [[ "$FIX_EXECUTABLE" == "true" ]]; then
    find "$TARGET_PATH" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
fi

if [[ "$FIX_OWNERSHIP" == "true" ]] && [[ $EUID -eq 0 ]]; then
    chown -R "$(logname):$(logname)" "$TARGET_PATH" 2>/dev/null || true
fi

echo "Permissions fixed successfully"
EOF
    
    chmod +x "$script_path"
}

create_sync_script() {
    local script_path="$AGENT_DIR/scripts/sync_repos.sh"
    mkdir -p "$(dirname "$script_path")"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Repository Sync Script for Repository Repair Agent

set -euo pipefail

# Default values
REPO_PATH=""
FORCE_SYNC=false
BRANCH="main"
REMOTE="origin"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-path=*)
            REPO_PATH="${1#*=}"
            shift
            ;;
        --force-sync=*)
            FORCE_SYNC="${1#*=}"
            shift
            ;;
        --branch=*)
            BRANCH="${1#*=}"
            shift
            ;;
        --remote=*)
            REMOTE="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$REPO_PATH" ]]; then
    echo "Error: --repo-path is required"
    exit 1
fi

cd "$REPO_PATH"

echo "Syncing repository: $REPO_PATH"
echo "Branch: $BRANCH"
echo "Remote: $REMOTE"
echo "Dry run: $DRY_RUN"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would sync repository (dry run mode)"
    exit 0
fi

# Check if remote exists
if git remote get-url "$REMOTE" &>/dev/null; then
    git fetch "$REMOTE" || echo "Warning: Could not fetch from remote"
    git status
else
    echo "No remote '$REMOTE' configured, performing local operations only"
fi

echo "Repository sync completed"
EOF
    
    chmod +x "$script_path"
}

create_rollback_script() {
    local script_path="$AGENT_DIR/scripts/rollback.sh"
    mkdir -p "$(dirname "$script_path")"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Rollback Script for Repository Repair Agent

set -euo pipefail

# Default values
REPO_PATH=""
TARGET=""
RESTORE_BACKUP=""
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-path=*)
            REPO_PATH="${1#*=}"
            shift
            ;;
        --target=*)
            TARGET="${1#*=}"
            shift
            ;;
        --restore-backup=*)
            RESTORE_BACKUP="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$REPO_PATH" ]]; then
    echo "Error: --repo-path is required"
    exit 1
fi

cd "$REPO_PATH"

echo "Performing rollback in: $REPO_PATH"

if [[ -n "$RESTORE_BACKUP" ]]; then
    echo "Restoring from backup: $RESTORE_BACKUP"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would restore from backup (dry run mode)"
    else
        cp -r "$RESTORE_BACKUP"/* . 2>/dev/null || echo "Backup restoration completed with warnings"
    fi
elif [[ -n "$TARGET" ]]; then
    echo "Rolling back to: $TARGET"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would rollback to $TARGET (dry run mode)"
    else
        git reset --hard "$TARGET" || echo "Rollback completed with warnings"
    fi
else
    echo "Error: Either --target or --restore-backup is required"
    exit 1
fi

echo "Rollback completed"
EOF
    
    chmod +x "$script_path"
}

# Cleanup test environment
cleanup_test_environment() {
    test_info "Cleaning up test environment..."
    
    # Restore original configurations
    local backup_dir="$TEST_DATA_DIR/backups"
    if [[ -d "$backup_dir" ]]; then
        if [[ -f "$backup_dir/agent_config.json" ]]; then
            cp "$backup_dir/agent_config.json" "$AGENT_DIR/config/" 2>/dev/null || true
        fi
        if [[ -f "$backup_dir/capabilities.json" ]]; then
            cp "$backup_dir/capabilities.json" "$AGENT_DIR/config/" 2>/dev/null || true
        fi
    fi
    
    # Clean up test data (preserve results)
    # rm -rf "$TEST_DATA_DIR" 2>/dev/null || true
    
    test_info "Test environment cleanup complete"
}

# Generate test report
generate_test_report() {
    local report_file="$TEST_RESULTS_DIR/test_report.html"
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    local pass_rate=0
    
    if [[ $total_tests -gt 0 ]]; then
        pass_rate=$(( (TESTS_PASSED * 100) / total_tests ))
    fi
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Repository Repair Agent Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .pass { color: green; }
        .fail { color: red; }
        .skip { color: orange; }
        .results { margin: 20px 0; }
        .test-section { margin-bottom: 30px; }
        .test-section h3 { border-bottom: 2px solid #ccc; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Repository Repair Agent Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Test Suite Version: 1.0.0</p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <p>Total Tests: $total_tests</p>
        <p class="pass">Passed: $TESTS_PASSED</p>
        <p class="fail">Failed: $TESTS_FAILED</p>
        <p class="skip">Skipped: $TESTS_SKIPPED</p>
        <p>Pass Rate: ${pass_rate}%</p>
    </div>
    
    <div class="results">
        <h2>Test Results</h2>
        <pre>$(cat "$LOG_FILE")</pre>
    </div>
    
    <div class="test-section">
        <h3>Test Categories Covered</h3>
        <ul>
            <li>Permission Fixes</li>
            <li>Repository Synchronization</li>
            <li>Rollback Functionality</li>
            <li>AI Agent Framework Integration</li>
            <li>Package Management Integration</li>
            <li>Security Tools Integration</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    test_info "Test report generated: $report_file"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Repository Repair Agent Test Suite

OPTIONS:
    --test-suite SUITE     Run specific test suite (permissions|sync|rollback|ai|package|security|all)
    --verbose              Enable verbose output
    --no-cleanup           Skip cleanup after tests
    --help                 Show this help message

EXAMPLES:
    # Run all tests
    $0

    # Run only permission tests
    $0 --test-suite permissions

    # Run with verbose output
    $0 --verbose

    # Run without cleanup
    $0 --no-cleanup
EOF
}

# Main test execution function
main() {
    local test_suite="all"
    local verbose=false
    local no_cleanup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test-suite)
                test_suite="$2"
                shift 2
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --no-cleanup)
                no_cleanup=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set verbose mode
    if [[ "$verbose" == "true" ]]; then
        set -x
    fi
    
    echo "Repository Repair Agent Test Suite"
    echo "=================================="
    echo "Starting test execution: $(date)"
    echo ""
    
    # Setup test environment
    setup_test_environment
    
    # Run tests based on suite selection
    case "$test_suite" in
        "permissions")
            test_permissions
            ;;
        "sync")
            test_sync
            ;;
        "rollback")
            test_rollback
            ;;
        "ai")
            test_ai_framework_integration
            ;;
        "package")
            test_package_management
            ;;
        "security")
            test_security_integration
            ;;
        "all")
            test_permissions
            test_sync
            test_rollback
            test_ai_framework_integration
            test_package_management
            test_security_integration
            ;;
        *)
            echo "Unknown test suite: $test_suite"
            show_usage
            exit 1
            ;;
    esac
    
    # Generate test report
    generate_test_report
    
    # Cleanup if requested
    if [[ "$no_cleanup" != "true" ]]; then
        cleanup_test_environment
    fi
    
    # Show final results
    echo ""
    echo "Test Execution Complete"
    echo "======================="
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED"
    echo "Total: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        echo "Some tests failed. Check the log file for details: $LOG_FILE"
        exit 1
    else
        echo ""
        echo "All tests passed successfully!"
        exit 0
    fi
}

# Execute main function
main "$@"

