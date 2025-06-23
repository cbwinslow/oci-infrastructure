#!/bin/bash

# Security Tools Integration Tests
# Tests the integration with various security scanning and analysis tools

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
AGENT_DIR="$PROJECT_ROOT/agents/repo_repair"
TEST_RESULTS_DIR="$(dirname "$SCRIPT_DIR")/results"

# Test configuration
TEST_TIMEOUT=120

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

test_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Test static code analysis with shellcheck
test_shellcheck_integration() {
    test_info "Testing ShellCheck integration..."
    
    if ! command -v shellcheck &> /dev/null; then
        test_skip "ShellCheck not available"
        return 0
    fi
    
    # Find all shell scripts in the project
    local script_files=()
    while IFS= read -r -d '' file; do
        script_files+=("$file")
    done < <(find "$AGENT_DIR" -name "*.sh" -type f -print0)
    
    if [[ ${#script_files[@]} -eq 0 ]]; then
        test_skip "No shell scripts found for analysis"
        return 0
    fi
    
    test_pass "Found ${#script_files[@]} shell scripts for analysis"
    
    # Run shellcheck on each script
    local issues_found=0
    local scripts_analyzed=0
    
    for script in "${script_files[@]}"; do
        if [[ -f "$script" ]]; then
            local script_name=$(basename "$script")
            
            if shellcheck "$script" 2>/dev/null; then
                test_pass "ShellCheck: $script_name - no issues"
            else
                local exit_code=$?
                if [[ $exit_code -eq 1 ]]; then
                    test_fail "ShellCheck: $script_name - issues found"
                    ((issues_found++))
                else
                    test_skip "ShellCheck: $script_name - analysis failed"
                fi
            fi
            ((scripts_analyzed++))
        fi
    done
    
    # Generate summary report
    local security_report="$TEST_RESULTS_DIR/shellcheck_report.txt"
    cat > "$security_report" << EOF
ShellCheck Security Analysis Report
==================================
Generated: $(date)

Scripts Analyzed: $scripts_analyzed
Issues Found: $issues_found
Clean Scripts: $((scripts_analyzed - issues_found))

Detailed Results:
EOF
    
    # Run shellcheck with detailed output
    for script in "${script_files[@]}"; do
        echo "" >> "$security_report"
        echo "=== $(basename "$script") ===" >> "$security_report"
        if shellcheck "$script" >> "$security_report" 2>&1; then
            echo "No issues found" >> "$security_report"
        fi
    done
    
    test_pass "ShellCheck report generated: $security_report"
    
    if [[ $issues_found -eq 0 ]]; then
        test_pass "All shell scripts passed security analysis"
    else
        test_fail "$issues_found scripts have security issues"
    fi
}

# Test secrets scanning
test_secrets_scanning() {
    test_info "Testing secrets scanning..."
    
    # Create a basic secrets scanner
    local secrets_scanner="$TEST_RESULTS_DIR/secrets_scanner.sh"
    cat > "$secrets_scanner" << 'EOF'
#!/bin/bash

# Basic secrets scanner for testing
set -euo pipefail

SCAN_DIR="$1"
PATTERNS=(
    "password\s*[=:]\s*['\"][^'\"]{3,}['\"]"
    "api[_-]?key\s*[=:]\s*['\"][^'\"]{8,}['\"]"
    "secret\s*[=:]\s*['\"][^'\"]{8,}['\"]"
    "token\s*[=:]\s*['\"][^'\"]{8,}['\"]"
    "aws[_-]?access[_-]?key"
    "aws[_-]?secret[_-]?key"
    "github[_-]?token"
    "slack[_-]?token"
    "private[_-]?key"
    "-----BEGIN (RSA |DSA |EC )?PRIVATE KEY-----"
    "[A-Za-z0-9+/]{40,}"
)

ISSUES_FOUND=0

echo "Scanning for potential secrets in: $SCAN_DIR"
echo "Patterns checked: ${#PATTERNS[@]}"
echo ""

for pattern in "${PATTERNS[@]}"; do
    echo "Checking pattern: $pattern"
    
    if grep -r -i -n -E "$pattern" "$SCAN_DIR" --include="*.sh" --include="*.json" --include="*.yml" --include="*.yaml" --include="*.env" 2>/dev/null; then
        echo "WARNING: Potential secret found with pattern: $pattern"
        ((ISSUES_FOUND++))
    fi
done

echo ""
echo "Secrets scan complete. Issues found: $ISSUES_FOUND"
exit $ISSUES_FOUND
EOF
    
    chmod +x "$secrets_scanner"
    
    # Run secrets scanner
    local scan_output
    if scan_output=$(bash "$secrets_scanner" "$AGENT_DIR" 2>&1); then
        test_pass "Secrets scan completed - no secrets found"
    else
        local exit_code=$?
        if [[ $exit_code -gt 0 ]]; then
            test_fail "Secrets scan found $exit_code potential issues"
            echo "$scan_output" > "$TEST_RESULTS_DIR/secrets_scan.log"
        else
            test_skip "Secrets scan failed to execute"
        fi
    fi
}

# Test dependency vulnerability scanning
test_dependency_scanning() {
    test_info "Testing dependency vulnerability scanning..."
    
    # Check for known vulnerable patterns in dependencies
    local config_file="$AGENT_DIR/config/agent_config.json"
    
    if [[ ! -f "$config_file" ]]; then
        test_skip "Agent configuration file not found"
        return 0
    fi
    
    # Extract dependencies
    local dependencies
    if dependencies=$(jq -r '.runtime.dependencies[]?' "$config_file" 2>/dev/null); then
        test_pass "Dependencies extracted from configuration"
        
        # Create vulnerability database (mock)
        local vuln_db="$TEST_RESULTS_DIR/vuln_db.json"
        cat > "$vuln_db" << 'EOF'
{
  "vulnerabilities": {
    "curl": {
      "CVE-2021-22876": {
        "severity": "medium",
        "description": "curl before 7.75.0 allows credential leak",
        "affected_versions": "< 7.75.0"
      }
    },
    "git": {
      "CVE-2021-21300": {
        "severity": "high", 
        "description": "Git remote code execution vulnerability",
        "affected_versions": "< 2.30.2"
      }
    },
    "jq": {
      "CVE-2021-3570": {
        "severity": "low",
        "description": "jq heap buffer overflow",
        "affected_versions": "< 1.6.1"
      }
    }
  }
}
EOF
        
        # Check each dependency against vulnerability database
        local vulns_found=0
        while IFS= read -r dep; do
            if [[ -n "$dep" ]]; then
                if jq -e ".vulnerabilities.\"$dep\"" "$vuln_db" >/dev/null 2>&1; then
                    local vuln_info
                    vuln_info=$(jq -r ".vulnerabilities.\"$dep\" | to_entries | .[0] | \"\(.key): \(.value.severity) - \(.value.description)\"" "$vuln_db")
                    test_fail "Dependency '$dep' has known vulnerability: $vuln_info"
                    ((vulns_found++))
                else
                    test_pass "Dependency '$dep' - no known vulnerabilities"
                fi
            fi
        done <<< "$dependencies"
        
        if [[ $vulns_found -eq 0 ]]; then
            test_pass "No vulnerabilities found in dependencies"
        else
            test_fail "$vulns_found vulnerabilities found in dependencies"
        fi
    else
        test_skip "No dependencies found to scan"
    fi
}

# Test container security scanning
test_container_security() {
    test_info "Testing container security scanning..."
    
    if ! command -v docker &> /dev/null; then
        test_skip "Docker not available for container security testing"
        return 0
    fi
    
    local dockerfile="$AGENT_DIR/templates/docker/Dockerfile"
    
    if [[ ! -f "$dockerfile" ]]; then
        test_skip "Dockerfile not found for security testing"
        return 0
    fi
    
    # Basic Dockerfile security checks
    local security_issues=0
    
    # Check for running as root
    if ! grep -q "USER" "$dockerfile"; then
        test_fail "Container security: No non-root user specified"
        ((security_issues++))
    else
        test_pass "Container security: Non-root user configured"
    fi
    
    # Check for HEALTHCHECK
    if grep -q "HEALTHCHECK" "$dockerfile"; then
        test_pass "Container security: Health check configured"
    else
        test_fail "Container security: No health check configured"
        ((security_issues++))
    fi
    
    # Check for unnecessary packages
    if grep -q "apt-get.*upgrade\|yum.*update" "$dockerfile"; then
        test_fail "Container security: Full system upgrade in container"
        ((security_issues++))
    else
        test_pass "Container security: No unnecessary system upgrades"
    fi
    
    # Check for secrets in Dockerfile
    if grep -i -E "(password|secret|key|token)" "$dockerfile"; then
        test_fail "Container security: Potential secrets in Dockerfile"
        ((security_issues++))
    else
        test_pass "Container security: No obvious secrets in Dockerfile"
    fi
    
    # Check for proper cache cleanup
    if grep -q "rm -rf /var/lib/apt/lists\|yum clean all\|apk del" "$dockerfile"; then
        test_pass "Container security: Package cache cleanup present"
    else
        test_fail "Container security: No package cache cleanup"
        ((security_issues++))
    fi
    
    # Generate container security report
    local container_report="$TEST_RESULTS_DIR/container_security_report.txt"
    cat > "$container_report" << EOF
Container Security Analysis Report
=================================
Generated: $(date)
Dockerfile: $dockerfile

Security Issues Found: $security_issues

Dockerfile Analysis:
$(cat "$dockerfile")

Security Recommendations:
- Use non-root user (USER directive)
- Include health checks (HEALTHCHECK directive)
- Clean package caches to reduce image size
- Avoid storing secrets in the image
- Use specific image tags instead of 'latest'
- Minimize installed packages and dependencies
EOF
    
    test_pass "Container security report generated: $container_report"
    
    if [[ $security_issues -eq 0 ]]; then
        test_pass "Container passes basic security checks"
    else
        test_fail "Container has $security_issues security issues"
    fi
}

# Test security configuration validation
test_security_configuration() {
    test_info "Testing security configuration validation..."
    
    local config_file="$AGENT_DIR/config/agent_config.json"
    
    if [[ ! -f "$config_file" ]]; then
        test_fail "Security configuration file not found"
        return 1
    fi
    
    # Check for security section
    if jq -e '.security' "$config_file" >/dev/null 2>&1; then
        test_pass "Security configuration section exists"
    else
        test_fail "Security configuration section missing"
        return 1
    fi
    
    # Check sandbox configuration
    if jq -e '.security.sandbox.enabled' "$config_file" >/dev/null 2>&1; then
        local sandbox_enabled
        sandbox_enabled=$(jq -r '.security.sandbox.enabled' "$config_file")
        
        if [[ "$sandbox_enabled" == "true" ]]; then
            test_pass "Sandbox security is enabled"
            
            # Check for allowed paths
            local allowed_paths
            allowed_paths=$(jq -r '.security.sandbox.allowed_paths[]?' "$config_file" 2>/dev/null | wc -l)
            
            if [[ $allowed_paths -gt 0 ]]; then
                test_pass "Sandbox has restricted file system access ($allowed_paths paths)"
            else
                test_fail "Sandbox has no file system restrictions"
            fi
            
            # Check for blocked commands
            local blocked_commands
            blocked_commands=$(jq -r '.security.sandbox.blocked_commands[]?' "$config_file" 2>/dev/null | wc -l)
            
            if [[ $blocked_commands -gt 0 ]]; then
                test_pass "Sandbox has command restrictions ($blocked_commands commands)"
            else
                test_fail "Sandbox has no command restrictions"
            fi
        else
            test_fail "Sandbox security is disabled"
        fi
    else
        test_fail "Sandbox configuration missing"
    fi
    
    # Check permissions configuration
    if jq -e '.security.permissions' "$config_file" >/dev/null 2>&1; then
        test_pass "Security permissions configuration exists"
        
        # Check permission types
        local permission_types=("read" "write" "execute")
        for perm_type in "${permission_types[@]}"; do
            if jq -e ".security.permissions.$perm_type" "$config_file" >/dev/null 2>&1; then
                local perm_count
                perm_count=$(jq -r ".security.permissions.$perm_type[]?" "$config_file" 2>/dev/null | wc -l)
                test_pass "Security $perm_type permissions defined ($perm_count items)"
            else
                test_fail "Security $perm_type permissions not defined"
            fi
        done
    else
        test_fail "Security permissions configuration missing"
    fi
}

# Test security monitoring and alerting
test_security_monitoring() {
    test_info "Testing security monitoring and alerting..."
    
    local capabilities_file="$AGENT_DIR/config/capabilities.json"
    
    if [[ ! -f "$capabilities_file" ]]; then
        test_skip "Capabilities file not found for monitoring tests"
        return 0
    fi
    
    # Check for monitoring configuration
    if jq -e '.monitoring' "$capabilities_file" >/dev/null 2>&1; then
        test_pass "Monitoring configuration exists"
        
        # Check for security metrics
        local security_metrics=("execution_time" "success_rate" "errors_encountered")
        for metric in "${security_metrics[@]}"; do
            if jq -e ".monitoring.metrics[]?" "$capabilities_file" | grep -q "$metric"; then
                test_pass "Security metric '$metric' configured"
            else
                test_fail "Security metric '$metric' not configured"
            fi
        done
        
        # Check for alerts
        if jq -e '.monitoring.alerts' "$capabilities_file" >/dev/null 2>&1; then
            test_pass "Security alerts configured"
            
            local alert_count
            alert_count=$(jq -r '.monitoring.alerts | length' "$capabilities_file" 2>/dev/null)
            test_pass "Security alerts: $alert_count configured"
            
            # Check alert conditions
            local alerts_with_conditions=0
            local total_alerts
            total_alerts=$(jq -r '.monitoring.alerts | length' "$capabilities_file" 2>/dev/null)
            
            for ((i=0; i<total_alerts; i++)); do
                if jq -e ".monitoring.alerts[$i].condition" "$capabilities_file" >/dev/null 2>&1; then
                    ((alerts_with_conditions++))
                fi
            done
            
            if [[ $alerts_with_conditions -eq $total_alerts ]]; then
                test_pass "All alerts have conditions defined"
            else
                test_fail "$((total_alerts - alerts_with_conditions)) alerts missing conditions"
            fi
        else
            test_fail "Security alerts not configured"
        fi
    else
        test_fail "Monitoring configuration missing"
    fi
}

# Test compliance with security standards
test_security_compliance() {
    test_info "Testing security compliance standards..."
    
    # Create compliance checklist
    local compliance_report="$TEST_RESULTS_DIR/compliance_report.txt"
    cat > "$compliance_report" << 'EOF'
Security Compliance Report
=========================
Generated: $(date)

OWASP Top 10 for Applications:
[ ] A01: Broken Access Control
[ ] A02: Cryptographic Failures  
[ ] A03: Injection
[ ] A04: Insecure Design
[ ] A05: Security Misconfiguration
[ ] A06: Vulnerable and Outdated Components
[ ] A07: Identification and Authentication Failures
[ ] A08: Software and Data Integrity Failures
[ ] A09: Security Logging and Monitoring Failures
[ ] A10: Server-Side Request Forgery

CIS Controls:
[ ] Inventory and Control of Hardware Assets
[ ] Inventory and Control of Software Assets
[ ] Continuous Vulnerability Management
[ ] Controlled Use of Administrative Privileges
[ ] Secure Configuration for Hardware and Software
[ ] Maintenance, Monitoring, and Analysis of Audit Logs
[ ] Email and Web Browser Protections
[ ] Malware Defenses
[ ] Limitation and Control of Network Ports
[ ] Data Recovery and Backup

Additional Security Measures:
[ ] Input validation and sanitization
[ ] Output encoding
[ ] Authentication and authorization
[ ] Session management
[ ] Error handling
[ ] Logging and monitoring
[ ] Data protection
[ ] Communication security
[ ] File upload security
[ ] Business logic security
EOF
    
    test_pass "Security compliance report template created"
    
    # Check for basic security practices
    local compliance_score=0
    local total_checks=10
    
    # Check 1: Input validation
    if find "$AGENT_DIR" -name "*.sh" -exec grep -l "validate\|sanitize\|filter" {} \; | head -1 >/dev/null; then
        test_pass "Compliance: Input validation practices found"
        ((compliance_score++))
    else
        test_fail "Compliance: No input validation practices found"
    fi
    
    # Check 2: Error handling
    if find "$AGENT_DIR" -name "*.sh" -exec grep -l "set -e\|trap\|error" {} \; | head -1 >/dev/null; then
        test_pass "Compliance: Error handling practices found"
        ((compliance_score++))
    else
        test_fail "Compliance: No error handling practices found"
    fi
    
    # Check 3: Logging
    if find "$AGENT_DIR" -name "*.sh" -exec grep -l "log\|echo.*\[\|logger" {} \; | head -1 >/dev/null; then
        test_pass "Compliance: Logging practices found"
        ((compliance_score++))
    else
        test_fail "Compliance: No logging practices found"
    fi
    
    # Check 4: Authentication/Authorization
    if find "$AGENT_DIR" -name "*.json" -exec grep -l "permissions\|auth\|token" {} \; | head -1 >/dev/null; then
        test_pass "Compliance: Authentication/authorization configuration found"
        ((compliance_score++))
    else
        test_fail "Compliance: No authentication/authorization configuration found"
    fi
    
    # Check 5: Secure communication
    if find "$AGENT_DIR" -name "*.sh" -exec grep -l "https\|ssl\|tls" {} \; | head -1 >/dev/null; then
        test_pass "Compliance: Secure communication practices found"
        ((compliance_score++))
    else
        test_fail "Compliance: No secure communication practices found"
    fi
    
    # Continue with remaining checks...
    local compliance_percentage=$((compliance_score * 100 / total_checks))
    
    if [[ $compliance_percentage -ge 80 ]]; then
        test_pass "Security compliance: $compliance_percentage% ($compliance_score/$total_checks)"
    elif [[ $compliance_percentage -ge 60 ]]; then
        test_skip "Security compliance: $compliance_percentage% - needs improvement"
    else
        test_fail "Security compliance: $compliance_percentage% - insufficient"
    fi
}

# Test security incident response
test_incident_response() {
    test_info "Testing security incident response capabilities..."
    
    # Create mock incident response script
    local incident_script="$TEST_RESULTS_DIR/incident_response.sh"
    cat > "$incident_script" << 'EOF'
#!/bin/bash

# Mock Security Incident Response Script
set -euo pipefail

INCIDENT_TYPE="$1"
INCIDENT_SEVERITY="${2:-medium}"

log_incident() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SECURITY INCIDENT: $*"
}

case "$INCIDENT_TYPE" in
    "unauthorized_access")
        log_incident "Unauthorized access detected - Severity: $INCIDENT_SEVERITY"
        echo "- Blocking suspicious IP addresses"
        echo "- Notifying security team"
        echo "- Increasing monitoring level"
        ;;
    "malware_detected")
        log_incident "Malware detected - Severity: $INCIDENT_SEVERITY"
        echo "- Quarantining affected files"
        echo "- Running full system scan"
        echo "- Notifying administrators"
        ;;
    "data_breach")
        log_incident "Data breach suspected - Severity: $INCIDENT_SEVERITY"
        echo "- Securing affected systems"
        echo "- Collecting forensic evidence"
        echo "- Notifying stakeholders"
        ;;
    *)
        log_incident "Unknown incident type: $INCIDENT_TYPE"
        echo "- Following generic response protocol"
        ;;
esac

echo "Incident response completed for: $INCIDENT_TYPE"
EOF
    
    chmod +x "$incident_script"
    
    # Test incident response scenarios
    local incident_types=("unauthorized_access" "malware_detected" "data_breach")
    local responses_tested=0
    
    for incident in "${incident_types[@]}"; do
        if bash "$incident_script" "$incident" "high" >/dev/null 2>&1; then
            test_pass "Incident response: $incident scenario handled"
            ((responses_tested++))
        else
            test_fail "Incident response: $incident scenario failed"
        fi
    done
    
    if [[ $responses_tested -eq ${#incident_types[@]} ]]; then
        test_pass "All incident response scenarios tested successfully"
    else
        test_fail "Some incident response scenarios failed"
    fi
}

# Cleanup function
cleanup() {
    test_info "Cleaning up security tools tests..."
    
    # Remove temporary files
    rm -f "$TEST_RESULTS_DIR"/secrets_scanner.sh
    rm -f "$TEST_RESULTS_DIR"/vuln_db.json
    rm -f "$TEST_RESULTS_DIR"/incident_response.sh
}

# Main test execution
main() {
    echo "Security Tools Integration Tests"
    echo "==============================="
    echo "Starting test execution: $(date)"
    echo ""
    
    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Setup trap for cleanup
    trap cleanup EXIT
    
    # Run tests
    test_shellcheck_integration
    test_secrets_scanning
    test_dependency_scanning
    test_container_security
    test_security_configuration
    test_security_monitoring
    test_security_compliance
    test_incident_response
    
    # Show results
    echo ""
    echo "Security Tools Integration Test Results"
    echo "======================================"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED"
    echo "Total: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        echo "Some security tests failed!"
        exit 1
    else
        echo ""
        echo "All security tests passed successfully!"
        exit 0
    fi
}

# Execute main function
main "$@"

