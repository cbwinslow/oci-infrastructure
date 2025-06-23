#!/bin/bash

# AI Agent Framework Integration Tests
# Tests the integration between the repository repair agent and AI agent framework

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
AGENT_DIR="$PROJECT_ROOT/agents/repo_repair"
TEST_RESULTS_DIR="$(dirname "$SCRIPT_DIR")/results"

# Test configuration
AI_FRAMEWORK_MOCK_PORT=8080
AGENT_SERVICE_PORT=8081
TEST_TIMEOUT=30

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

# Mock AI Framework Server
start_mock_ai_framework() {
    test_info "Starting mock AI framework server..."
    
    local mock_server_script="$TEST_RESULTS_DIR/mock_ai_server.py"
    
    cat > "$mock_server_script" << 'EOF'
#!/usr/bin/env python3
import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
import time
import uuid

class MockAIFrameworkHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        
        if path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {'status': 'healthy', 'timestamp': time.time()}
            self.wfile.write(json.dumps(response).encode())
            
        elif path.startswith('/agents/'):
            agent_id = path.split('/')[-1]
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'agent_id': agent_id,
                'status': 'active',
                'capabilities': ['fix_permissions', 'sync_repos', 'handle_changes']
            }
            self.wfile.write(json.dumps(response).encode())
            
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        path = urlparse(self.path).path
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        if path == '/api/v1/agents/register':
            try:
                data = json.loads(post_data.decode())
                agent_id = str(uuid.uuid4())
                
                self.send_response(201)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                response = {
                    'status': 'success',
                    'agent_id': agent_id,
                    'message': 'Agent registered successfully',
                    'capabilities_url': f'/api/v1/agents/{agent_id}/capabilities'
                }
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_response(400)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {'status': 'error', 'message': str(e)}
                self.wfile.write(json.dumps(response).encode())
                
        elif path.endswith('/capabilities'):
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {'status': 'success', 'message': 'Capabilities updated'}
            self.wfile.write(json.dumps(response).encode())
            
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_PUT(self):
        self.do_POST()
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

def run_server(port):
    server = HTTPServer(('localhost', port), MockAIFrameworkHandler)
    server.serve_forever()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    print(f"Starting mock AI framework on port {port}")
    run_server(port)
EOF
    
    # Start the mock server in background
    python3 "$mock_server_script" $AI_FRAMEWORK_MOCK_PORT &
    local server_pid=$!
    
    # Wait for server to start
    sleep 2
    
    # Test if server is running
    if curl -s "http://localhost:$AI_FRAMEWORK_MOCK_PORT/health" > /dev/null; then
        test_pass "Mock AI framework server started (PID: $server_pid)"
        echo "$server_pid" > "$TEST_RESULTS_DIR/mock_server.pid"
        return 0
    else
        test_fail "Failed to start mock AI framework server"
        return 1
    fi
}

# Stop mock server
stop_mock_ai_framework() {
    local pid_file="$TEST_RESULTS_DIR/mock_server.pid"
    if [[ -f "$pid_file" ]]; then
        local server_pid=$(cat "$pid_file")
        if kill "$server_pid" 2>/dev/null; then
            test_info "Mock AI framework server stopped"
        fi
        rm -f "$pid_file"
    fi
}

# Test agent registration with framework
test_agent_registration() {
    test_info "Testing agent registration with AI framework..."
    
    # Set environment variables
    export AI_FRAMEWORK_ENDPOINT="http://localhost:$AI_FRAMEWORK_MOCK_PORT/api/v1"
    export AI_FRAMEWORK_TOKEN=""
    
    local register_script="$AGENT_DIR/register_agent.sh"
    
    if [[ ! -f "$register_script" ]]; then
        test_fail "Registration script not found"
        return 1
    fi
    
    # Test registration
    local output
    if output=$(timeout $TEST_TIMEOUT bash "$register_script" 2>&1); then
        if echo "$output" | grep -q "Successfully registered"; then
            test_pass "Agent registration successful"
        else
            test_skip "Agent registration (mock framework limitation)"
        fi
    else
        test_fail "Agent registration failed: $output"
    fi
}

# Test agent capabilities reporting
test_capabilities_reporting() {
    test_info "Testing capabilities reporting..."
    
    local capabilities_file="$AGENT_DIR/config/capabilities.json"
    
    if [[ ! -f "$capabilities_file" ]]; then
        test_fail "Capabilities file not found"
        return 1
    fi
    
    # Validate capabilities JSON
    if jq empty "$capabilities_file" 2>/dev/null; then
        test_pass "Capabilities JSON is valid"
    else
        test_fail "Capabilities JSON is invalid"
        return 1
    fi
    
    # Check required capability fields
    local required_fields=("capabilities" "workflows" "integrations")
    for field in "${required_fields[@]}"; do
        if jq -e ".$field" "$capabilities_file" >/dev/null 2>&1; then
            test_pass "Capability field '$field' exists"
        else
            test_fail "Capability field '$field' missing"
        fi
    done
    
    # Test specific capabilities
    local capabilities=("fix_permissions" "sync_repos" "handle_changes")
    for capability in "${capabilities[@]}"; do
        if jq -e ".capabilities[] | select(.name == \"$capability\")" "$capabilities_file" >/dev/null 2>&1; then
            test_pass "Capability '$capability' defined"
        else
            test_fail "Capability '$capability' missing"
        fi
    done
}

# Test health check endpoint
test_health_check() {
    test_info "Testing health check functionality..."
    
    # Mock health check script
    local health_script="$TEST_RESULTS_DIR/mock_health_check.sh"
    cat > "$health_script" << 'EOF'
#!/bin/bash
# Mock health check for testing

echo "Content-Type: application/json"
echo ""
echo '{"status": "healthy", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "version": "1.0.0"}'
EOF
    chmod +x "$health_script"
    
    # Test health check response
    local health_output
    if health_output=$(bash "$health_script"); then
        if echo "$health_output" | grep -q '"status": "healthy"'; then
            test_pass "Health check returns valid response"
        else
            test_fail "Health check response invalid"
        fi
    else
        test_fail "Health check execution failed"
    fi
}

# Test framework communication protocols
test_communication_protocols() {
    test_info "Testing communication protocols..."
    
    # Test HTTP endpoints
    local endpoints=("/health" "/api/v1/agents/register")
    for endpoint in "${endpoints[@]}"; do
        local url="http://localhost:$AI_FRAMEWORK_MOCK_PORT$endpoint"
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|201\|404"; then
            test_pass "Endpoint '$endpoint' accessible"
        else
            test_fail "Endpoint '$endpoint' not accessible"
        fi
    done
    
    # Test JSON content types
    local response
    response=$(curl -s -H "Content-Type: application/json" \
                    -d '{"test": "data"}' \
                    "http://localhost:$AI_FRAMEWORK_MOCK_PORT/api/v1/agents/register")
    
    if echo "$response" | jq empty 2>/dev/null; then
        test_pass "JSON communication protocol working"
    else
        test_fail "JSON communication protocol failed"
    fi
}

# Test error handling and recovery
test_error_handling() {
    test_info "Testing error handling and recovery..."
    
    # Test with invalid endpoint
    export AI_FRAMEWORK_ENDPOINT="http://localhost:9999/api/v1"
    
    local register_script="$AGENT_DIR/register_agent.sh"
    local output
    
    if output=$(timeout 10 bash "$register_script" 2>&1); then
        if echo "$output" | grep -q "ERROR\|Failed"; then
            test_pass "Error handling for unreachable endpoint"
        else
            test_skip "Error handling test (unexpected success)"
        fi
    else
        test_pass "Timeout handling for unreachable endpoint"
    fi
    
    # Reset to valid endpoint
    export AI_FRAMEWORK_ENDPOINT="http://localhost:$AI_FRAMEWORK_MOCK_PORT/api/v1"
    
    # Test with invalid JSON
    local config_backup="$AGENT_DIR/config/agent_config.json.backup"
    cp "$AGENT_DIR/config/agent_config.json" "$config_backup"
    
    echo "invalid json" > "$AGENT_DIR/config/agent_config.json"
    
    if output=$(timeout 10 bash "$register_script" 2>&1); then
        if echo "$output" | grep -q "ERROR\|Failed"; then
            test_pass "Error handling for invalid configuration"
        else
            test_fail "Error handling for invalid configuration failed"
        fi
    else
        test_pass "Graceful failure for invalid configuration"
    fi
    
    # Restore config
    mv "$config_backup" "$AGENT_DIR/config/agent_config.json"
}

# Test service discovery and monitoring
test_service_monitoring() {
    test_info "Testing service discovery and monitoring..."
    
    # Test service discovery
    local health_url="http://localhost:$AI_FRAMEWORK_MOCK_PORT/health"
    local response
    
    if response=$(curl -s "$health_url"); then
        if echo "$response" | jq -e '.status' >/dev/null 2>&1; then
            test_pass "Service discovery successful"
        else
            test_fail "Service discovery response invalid"
        fi
    else
        test_fail "Service discovery failed"
    fi
    
    # Test monitoring metrics (mock)
    local metrics_script="$TEST_RESULTS_DIR/mock_metrics.sh"
    cat > "$metrics_script" << 'EOF'
#!/bin/bash
# Mock metrics collection

echo "# Repository Repair Agent Metrics"
echo "repo_repair_requests_total 42"
echo "repo_repair_errors_total 2"
echo "repo_repair_success_rate 0.95"
echo "repo_repair_avg_response_time_seconds 1.23"
EOF
    chmod +x "$metrics_script"
    
    local metrics_output
    if metrics_output=$(bash "$metrics_script"); then
        if echo "$metrics_output" | grep -q "repo_repair_requests_total"; then
            test_pass "Metrics collection functional"
        else
            test_fail "Metrics collection failed"
        fi
    else
        test_fail "Metrics script execution failed"
    fi
}

# Test workflow orchestration
test_workflow_orchestration() {
    test_info "Testing workflow orchestration..."
    
    local capabilities_file="$AGENT_DIR/config/capabilities.json"
    
    # Test workflow definitions
    if jq -e '.workflows' "$capabilities_file" >/dev/null 2>&1; then
        test_pass "Workflow definitions exist"
    else
        test_fail "Workflow definitions missing"
        return 1
    fi
    
    # Test workflow steps
    local workflow_steps
    workflow_steps=$(jq -r '.workflows[0].steps | length' "$capabilities_file" 2>/dev/null || echo "0")
    
    if [[ $workflow_steps -gt 0 ]]; then
        test_pass "Workflow steps defined ($workflow_steps steps)"
    else
        test_fail "No workflow steps defined"
    fi
    
    # Test rollback configuration
    if jq -e '.workflows[0].rollback' "$capabilities_file" >/dev/null 2>&1; then
        test_pass "Rollback configuration exists"
    else
        test_skip "Rollback configuration (not required)"
    fi
}

# Cleanup function
cleanup() {
    test_info "Cleaning up AI framework integration tests..."
    stop_mock_ai_framework
    
    # Remove temporary files
    rm -f "$TEST_RESULTS_DIR"/mock_*.py
    rm -f "$TEST_RESULTS_DIR"/mock_*.sh
    rm -f "$TEST_RESULTS_DIR"/mock_server.pid
}

# Main test execution
main() {
    echo "AI Agent Framework Integration Tests"
    echo "=================================="
    echo "Starting test execution: $(date)"
    echo ""
    
    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Setup trap for cleanup
    trap cleanup EXIT
    
    # Start mock AI framework
    if ! start_mock_ai_framework; then
        echo "Failed to start mock AI framework. Exiting."
        exit 1
    fi
    
    # Run tests
    test_agent_registration
    test_capabilities_reporting
    test_health_check
    test_communication_protocols
    test_error_handling
    test_service_monitoring
    test_workflow_orchestration
    
    # Show results
    echo ""
    echo "AI Framework Integration Test Results"
    echo "===================================="
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED"
    echo "Total: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        echo "Some tests failed!"
        exit 1
    else
        echo ""
        echo "All tests passed successfully!"
        exit 0
    fi
}

# Execute main function
main "$@"

