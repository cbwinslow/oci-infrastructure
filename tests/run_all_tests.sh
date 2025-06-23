#!/bin/bash

# Master Test Runner for Repository Repair Agent
# Executes all test suites and generates comprehensive reports

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
INTEGRATION_DIR="$SCRIPT_DIR/integration"

# Test configuration
PARALLEL_EXECUTION=false
GENERATE_REPORTS=true
UPLOAD_RESULTS=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Test suite tracking
declare -A SUITE_RESULTS
declare -A SUITE_DURATIONS
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$TEST_RESULTS_DIR/master_test.log"
}

suite_pass() {
    echo -e "${GREEN}[SUITE PASS]${NC} $1"
    log "SUITE PASS: $1"
    ((PASSED_SUITES++))
}

suite_fail() {
    echo -e "${RED}[SUITE FAIL]${NC} $1"
    log "SUITE FAIL: $1"
    ((FAILED_SUITES++))
}

suite_info() {
    echo -e "${BLUE}[SUITE INFO]${NC} $1"
    log "SUITE INFO: $1"
}

# Setup test environment
setup_test_environment() {
    suite_info "Setting up master test environment..."
    
    # Create all necessary directories
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$TEST_RESULTS_DIR/individual_reports"
    mkdir -p "$TEST_RESULTS_DIR/artifacts"
    
    # Initialize master log
    echo "Master Test Suite Started: $(date)" > "$TEST_RESULTS_DIR/master_test.log"
    
    # Create test summary file
    cat > "$TEST_RESULTS_DIR/test_summary.json" << 'EOF'
{
  "test_run": {
    "start_time": "",
    "end_time": "",
    "duration": "",
    "total_suites": 0,
    "passed_suites": 0,
    "failed_suites": 0,
    "test_environment": {},
    "suite_results": {}
  }
}
EOF
    
    # Record test environment
    local env_info="$TEST_RESULTS_DIR/environment_info.txt"
    cat > "$env_info" << EOF
Test Environment Information
===========================
Generated: $(date)

System Information:
- OS: $(uname -s)
- Kernel: $(uname -r)
- Architecture: $(uname -m)
- Hostname: $(hostname)
- User: $(whoami)

Software Versions:
- Bash: $BASH_VERSION
- Git: $(git --version 2>/dev/null || echo "Not installed")
- Docker: $(docker --version 2>/dev/null || echo "Not installed")
- Python: $(python3 --version 2>/dev/null || echo "Not installed")
- Node.js: $(node --version 2>/dev/null || echo "Not installed")
- jq: $(jq --version 2>/dev/null || echo "Not installed")

Available Tools:
- curl: $(command -v curl >/dev/null && echo "Available" || echo "Not available")
- shellcheck: $(command -v shellcheck >/dev/null && echo "Available" || echo "Not available")
- npm: $(command -v npm >/dev/null && echo "Available" || echo "Not available")
- pip: $(command -v pip >/dev/null && echo "Available" || echo "Not available")

Project Information:
- Project Root: $PROJECT_ROOT
- Test Directory: $SCRIPT_DIR
- Agent Directory: $PROJECT_ROOT/agents/repo_repair
EOF
    
    suite_info "Test environment setup complete"
}

# Run individual test suite
run_test_suite() {
    local suite_name="$1"
    local suite_script="$2"
    local suite_args="${3:-}"
    
    suite_info "Running test suite: $suite_name"
    
    if [[ ! -f "$suite_script" ]]; then
        suite_fail "$suite_name - Script not found: $suite_script"
        SUITE_RESULTS["$suite_name"]="MISSING"
        return 1
    fi
    
    if [[ ! -x "$suite_script" ]]; then
        chmod +x "$suite_script"
    fi
    
    local start_time=$(date +%s)
    local suite_log="$TEST_RESULTS_DIR/individual_reports/${suite_name}.log"
    local suite_report="$TEST_RESULTS_DIR/individual_reports/${suite_name}_report.txt"
    
    # Run the test suite
    local exit_code=0
    if bash "$suite_script" $suite_args > "$suite_log" 2>&1; then
        suite_pass "$suite_name completed successfully"
        SUITE_RESULTS["$suite_name"]="PASS"
    else
        exit_code=$?
        suite_fail "$suite_name failed with exit code $exit_code"
        SUITE_RESULTS["$suite_name"]="FAIL"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    SUITE_DURATIONS["$suite_name"]=$duration
    
    # Extract test results from log
    local passed_tests=$(grep -c "\[PASS\]" "$suite_log" 2>/dev/null || echo "0")
    local failed_tests=$(grep -c "\[FAIL\]" "$suite_log" 2>/dev/null || echo "0")
    local skipped_tests=$(grep -c "\[SKIP\]" "$suite_log" 2>/dev/null || echo "0")
    
    # Generate individual suite report
    cat > "$suite_report" << EOF
Test Suite Report: $suite_name
==============================
Generated: $(date)

Execution Summary:
- Status: ${SUITE_RESULTS["$suite_name"]}
- Duration: ${duration}s
- Exit Code: $exit_code

Test Results:
- Passed: $passed_tests
- Failed: $failed_tests  
- Skipped: $skipped_tests
- Total: $((passed_tests + failed_tests + skipped_tests))

Log Output:
$(cat "$suite_log")
EOF
    
    log "$suite_name: ${SUITE_RESULTS["$suite_name"]} (${duration}s) - P:$passed_tests F:$failed_tests S:$skipped_tests"
    
    return $exit_code
}

# Run all test suites
run_all_suites() {
    suite_info "Starting execution of all test suites..."
    
    local start_time=$(date +%s)
    
    # Main test suite
    run_test_suite "main_suite" "$SCRIPT_DIR/test_suite.sh" "--test-suite all"
    ((TOTAL_SUITES++))
    
    # Integration test suites
    if [[ -d "$INTEGRATION_DIR" ]]; then
        for integration_test in "$INTEGRATION_DIR"/*.sh; do
            if [[ -f "$integration_test" ]]; then
                local test_name=$(basename "$integration_test" .sh)
                run_test_suite "$test_name" "$integration_test"
                ((TOTAL_SUITES++))
            fi
        done
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    suite_info "All test suites completed in ${total_duration}s"
    
    # Update summary
    jq --arg start "$(date -d "@$start_time" '+%Y-%m-%d %H:%M:%S')" \
       --arg end "$(date -d "@$end_time" '+%Y-%m-%d %H:%M:%S')" \
       --arg duration "${total_duration}s" \
       --argjson total "$TOTAL_SUITES" \
       --argjson passed "$PASSED_SUITES" \
       --argjson failed "$FAILED_SUITES" \
       '.test_run.start_time = $start | 
        .test_run.end_time = $end |
        .test_run.duration = $duration |
        .test_run.total_suites = $total |
        .test_run.passed_suites = $passed |
        .test_run.failed_suites = $failed' \
       "$TEST_RESULTS_DIR/test_summary.json" > "$TEST_RESULTS_DIR/test_summary.tmp"
    
    mv "$TEST_RESULTS_DIR/test_summary.tmp" "$TEST_RESULTS_DIR/test_summary.json"
}

# Generate comprehensive test report
generate_comprehensive_report() {
    if [[ "$GENERATE_REPORTS" != "true" ]]; then
        return 0
    fi
    
    suite_info "Generating comprehensive test report..."
    
    local report_file="$TEST_RESULTS_DIR/comprehensive_test_report.html"
    local pass_rate=0
    
    if [[ $TOTAL_SUITES -gt 0 ]]; then
        pass_rate=$(( (PASSED_SUITES * 100) / TOTAL_SUITES ))
    fi
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Repository Repair Agent - Comprehensive Test Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            padding: 30px;
            background-color: #f8f9fa;
        }
        .metric {
            text-align: center;
            padding: 20px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .metric-label {
            color: #666;
            font-size: 0.9em;
        }
        .pass { color: #28a745; }
        .fail { color: #dc3545; }
        .skip { color: #ffc107; }
        .content {
            padding: 30px;
        }
        .suite-grid {
            display: grid;
            gap: 20px;
            margin: 20px 0;
        }
        .suite-card {
            border: 1px solid #dee2e6;
            border-radius: 8px;
            overflow: hidden;
        }
        .suite-header {
            padding: 15px 20px;
            background-color: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .suite-status {
            padding: 4px 12px;
            border-radius: 20px;
            color: white;
            font-weight: bold;
            font-size: 0.8em;
        }
        .status-pass { background-color: #28a745; }
        .status-fail { background-color: #dc3545; }
        .status-missing { background-color: #6c757d; }
        .suite-body {
            padding: 20px;
        }
        .progress-bar {
            width: 100%;
            height: 20px;
            background-color: #e9ecef;
            border-radius: 10px;
            overflow: hidden;
            margin: 20px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745 0%, #20c997 100%);
            transition: width 0.3s ease;
        }
        .details {
            margin-top: 30px;
        }
        .collapsible {
            cursor: pointer;
            padding: 15px;
            background-color: #f8f9fa;
            border: none;
            width: 100%;
            text-align: left;
            font-size: 1.1em;
            font-weight: bold;
        }
        .collapsible:hover {
            background-color: #e9ecef;
        }
        .content-panel {
            display: none;
            padding: 20px;
            background-color: white;
            border: 1px solid #dee2e6;
            border-top: none;
        }
        .footer {
            background-color: #343a40;
            color: white;
            text-align: center;
            padding: 20px;
        }
        pre {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Repository Repair Agent</h1>
            <p>Comprehensive Test Report - $(date)</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <div class="metric-value">$TOTAL_SUITES</div>
                <div class="metric-label">Total Suites</div>
            </div>
            <div class="metric">
                <div class="metric-value pass">$PASSED_SUITES</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric">
                <div class="metric-value fail">$FAILED_SUITES</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric">
                <div class="metric-value">${pass_rate}%</div>
                <div class="metric-label">Pass Rate</div>
            </div>
        </div>
        
        <div class="content">
            <h2>Overall Progress</h2>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${pass_rate}%"></div>
            </div>
            
            <h2>Test Suite Results</h2>
            <div class="suite-grid">
EOF
    
    # Add individual suite results
    for suite_name in "${!SUITE_RESULTS[@]}"; do
        local status="${SUITE_RESULTS[$suite_name]}"
        local duration="${SUITE_DURATIONS[$suite_name]:-0}"
        local status_class=""
        
        case "$status" in
            "PASS") status_class="status-pass" ;;
            "FAIL") status_class="status-fail" ;;
            *) status_class="status-missing" ;;
        esac
        
        cat >> "$report_file" << EOF
                <div class="suite-card">
                    <div class="suite-header">
                        <h3>$suite_name</h3>
                        <span class="suite-status $status_class">$status</span>
                    </div>
                    <div class="suite-body">
                        <p><strong>Duration:</strong> ${duration}s</p>
                        <p><strong>Log File:</strong> individual_reports/${suite_name}.log</p>
                        <p><strong>Report:</strong> individual_reports/${suite_name}_report.txt</p>
                    </div>
                </div>
EOF
    done
    
    cat >> "$report_file" << EOF
            </div>
            
            <div class="details">
                <button class="collapsible">Environment Information</button>
                <div class="content-panel">
                    <pre>$(cat "$TEST_RESULTS_DIR/environment_info.txt")</pre>
                </div>
                
                <button class="collapsible">Test Summary JSON</button>
                <div class="content-panel">
                    <pre>$(cat "$TEST_RESULTS_DIR/test_summary.json" | jq .)</pre>
                </div>
                
                <button class="collapsible">Master Test Log</button>
                <div class="content-panel">
                    <pre>$(tail -50 "$TEST_RESULTS_DIR/master_test.log")</pre>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Generated by Repository Repair Agent Test Suite</p>
            <p>Report generated: $(date)</p>
        </div>
    </div>
    
    <script>
        // Add collapsible functionality
        var coll = document.getElementsByClassName("collapsible");
        for (var i = 0; i < coll.length; i++) {
            coll[i].addEventListener("click", function() {
                this.classList.toggle("active");
                var content = this.nextElementSibling;
                if (content.style.display === "block") {
                    content.style.display = "none";
                } else {
                    content.style.display = "block";
                }
            });
        }
    </script>
</body>
</html>
EOF
    
    suite_info "Comprehensive test report generated: $report_file"
}

# Display final results
display_final_results() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                    REPOSITORY REPAIR AGENT TEST RESULTS${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local pass_rate=0
    if [[ $TOTAL_SUITES -gt 0 ]]; then
        pass_rate=$(( (PASSED_SUITES * 100) / TOTAL_SUITES ))
    fi
    
    echo -e "Total Test Suites: ${BOLD}$TOTAL_SUITES${NC}"
    echo -e "Passed Suites: ${GREEN}${BOLD}$PASSED_SUITES${NC}"
    echo -e "Failed Suites: ${RED}${BOLD}$FAILED_SUITES${NC}"
    echo -e "Overall Pass Rate: ${BOLD}${pass_rate}%${NC}"
    echo ""
    
    echo -e "${BOLD}Individual Suite Results:${NC}"
    echo "┌─────────────────────────────────┬─────────┬─────────────┐"
    echo "│ Suite Name                      │ Status  │ Duration    │"
    echo "├─────────────────────────────────┼─────────┼─────────────┤"
    
    for suite_name in "${!SUITE_RESULTS[@]}"; do
        local status="${SUITE_RESULTS[$suite_name]}"
        local duration="${SUITE_DURATIONS[$suite_name]:-0}"
        local status_display=""
        
        case "$status" in
            "PASS") status_display="${GREEN}PASS${NC}   " ;;
            "FAIL") status_display="${RED}FAIL${NC}   " ;;
            *) status_display="${YELLOW}MISSING${NC}" ;;
        esac
        
        printf "│ %-31s │ %s │ %8ss   │\n" "$suite_name" "$status_display" "$duration"
    done
    
    echo "└─────────────────────────────────┴─────────┴─────────────┘"
    echo ""
    
    echo -e "${BOLD}Generated Reports:${NC}"
    echo "• Comprehensive HTML Report: $TEST_RESULTS_DIR/comprehensive_test_report.html"
    echo "• Test Summary JSON: $TEST_RESULTS_DIR/test_summary.json"
    echo "• Environment Info: $TEST_RESULTS_DIR/environment_info.txt"
    echo "• Master Log: $TEST_RESULTS_DIR/master_test.log"
    echo "• Individual Reports: $TEST_RESULTS_DIR/individual_reports/"
    echo ""
    
    if [[ $FAILED_SUITES -gt 0 ]]; then
        echo -e "${RED}${BOLD}⚠️  Some test suites failed. Please review the reports for details.${NC}"
        return 1
    else
        echo -e "${GREEN}${BOLD}✅ All test suites passed successfully!${NC}"
        return 0
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Repository Repair Agent Master Test Runner

OPTIONS:
    --parallel              Run test suites in parallel (experimental)
    --no-reports           Skip comprehensive report generation
    --upload-results       Upload test results to remote location
    --help                 Show this help message

EXAMPLES:
    # Run all tests with default settings
    $0

    # Run tests in parallel mode
    $0 --parallel

    # Run tests without generating reports
    $0 --no-reports

    # Run tests and upload results
    $0 --upload-results
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --parallel)
                PARALLEL_EXECUTION=true
                shift
                ;;
            --no-reports)
                GENERATE_REPORTS=false
                shift
                ;;
            --upload-results)
                UPLOAD_RESULTS=true
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
}

# Cleanup function
cleanup() {
    suite_info "Performing cleanup..."
    
    # Archive logs if needed
    if [[ "$UPLOAD_RESULTS" == "true" ]]; then
        local archive_name="test_results_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$TEST_RESULTS_DIR/$archive_name" -C "$TEST_RESULTS_DIR" .
        suite_info "Test results archived: $archive_name"
    fi
}

# Main execution function
main() {
    echo -e "${BOLD}Repository Repair Agent - Master Test Runner${NC}"
    echo -e "${BOLD}=============================================${NC}"
    echo "Starting comprehensive test execution: $(date)"
    echo ""
    
    parse_arguments "$@"
    
    # Setup trap for cleanup
    trap cleanup EXIT
    
    setup_test_environment
    run_all_suites
    generate_comprehensive_report
    
    # Display results and exit with appropriate code
    if display_final_results; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"

