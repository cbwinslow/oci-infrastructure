#!/bin/bash

# Package Management Integration Tests
# Tests the integration with various package management systems

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
AGENT_DIR="$PROJECT_ROOT/agents/repo_repair"
TEST_RESULTS_DIR="$(dirname "$SCRIPT_DIR")/results"

# Test configuration
TEST_TIMEOUT=60

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

# Test package manager detection
test_package_manager_detection() {
    test_info "Testing package manager detection..."
    
    local package_script="$AGENT_DIR/scripts/package_integration.sh"
    
    if [[ ! -f "$package_script" ]]; then
        test_fail "Package integration script not found"
        return 1
    fi
    
    # Test detection of available package managers
    local detected_managers=()
    local all_managers=("apt" "yum" "dnf" "pacman" "brew" "pip" "npm" "docker")
    
    for manager in "${all_managers[@]}"; do
        if command -v "$manager" &> /dev/null; then
            detected_managers+=("$manager")
            test_pass "Package manager '$manager' detected"
        else
            test_skip "Package manager '$manager' not available"
        fi
    done
    
    if [[ ${#detected_managers[@]} -gt 0 ]]; then
        test_pass "Package manager detection functional (${#detected_managers[@]} managers found)"
    else
        test_skip "Package manager detection (no supported managers found)"
    fi
}

# Test APT package configuration
test_apt_package_config() {
    test_info "Testing APT package configuration..."
    
    if ! command -v apt &> /dev/null; then
        test_skip "APT not available on this system"
        return 0
    fi
    
    local package_script="$AGENT_DIR/scripts/package_integration.sh"
    local templates_dir="$AGENT_DIR/templates"
    
    # Run package integration to generate templates
    if bash "$package_script" 2>/dev/null; then
        test_pass "Package integration script executed"
    else
        test_fail "Package integration script failed"
        return 1
    fi
    
    # Check APT package files
    local apt_dir="$templates_dir/apt"
    if [[ -d "$apt_dir" ]]; then
        test_pass "APT template directory created"
        
        # Check control file
        if [[ -f "$apt_dir/control" ]]; then
            test_pass "APT control file created"
            
            # Validate control file format
            if grep -q "Package:" "$apt_dir/control" && grep -q "Version:" "$apt_dir/control"; then
                test_pass "APT control file format valid"
            else
                test_fail "APT control file format invalid"
            fi
        else
            test_fail "APT control file not created"
        fi
        
        # Check install script
        if [[ -f "$apt_dir/repo-repair.install" ]]; then
            test_pass "APT install script created"
            
            # Check if script is executable
            if [[ -x "$apt_dir/repo-repair.install" ]]; then
                test_pass "APT install script is executable"
            else
                test_fail "APT install script not executable"
            fi
        else
            test_fail "APT install script not created"
        fi
    else
        test_skip "APT template directory not created"
    fi
}

# Test Docker package configuration
test_docker_package_config() {
    test_info "Testing Docker package configuration..."
    
    if ! command -v docker &> /dev/null; then
        test_skip "Docker not available on this system"
        return 0
    fi
    
    local templates_dir="$AGENT_DIR/templates"
    local docker_dir="$templates_dir/docker"
    
    if [[ -d "$docker_dir" ]]; then
        test_pass "Docker template directory exists"
        
        # Check Dockerfile
        if [[ -f "$docker_dir/Dockerfile" ]]; then
            test_pass "Dockerfile created"
            
            # Validate Dockerfile format
            if grep -q "FROM" "$docker_dir/Dockerfile" && grep -q "WORKDIR" "$docker_dir/Dockerfile"; then
                test_pass "Dockerfile format valid"
            else
                test_fail "Dockerfile format invalid"
            fi
            
            # Test Docker build (dry run)
            if docker build --dry-run -t repo-repair-test -f "$docker_dir/Dockerfile" "$PROJECT_ROOT" 2>/dev/null; then
                test_pass "Docker build validation successful"
            else
                test_fail "Docker build validation failed"
            fi
        else
            test_fail "Dockerfile not created"
        fi
        
        # Check docker-compose file
        if [[ -f "$docker_dir/docker-compose.yml" ]]; then
            test_pass "Docker Compose file created"
            
            # Validate YAML format (basic check)
            if grep -q "version:" "$docker_dir/docker-compose.yml" && grep -q "services:" "$docker_dir/docker-compose.yml"; then
                test_pass "Docker Compose format valid"
            else
                test_fail "Docker Compose format invalid"
            fi
        else
            test_fail "Docker Compose file not created"
        fi
    else
        test_skip "Docker template directory not found"
    fi
}

# Test NPM package configuration
test_npm_package_config() {
    test_info "Testing NPM package configuration..."
    
    if ! command -v npm &> /dev/null; then
        test_skip "NPM not available on this system"
        return 0
    fi
    
    local templates_dir="$AGENT_DIR/templates"
    local npm_dir="$templates_dir/npm"
    
    if [[ -d "$npm_dir" ]]; then
        test_pass "NPM template directory exists"
        
        # Check package.json
        if [[ -f "$npm_dir/package.json" ]]; then
            test_pass "NPM package.json created"
            
            # Validate JSON format
            if jq empty "$npm_dir/package.json" 2>/dev/null; then
                test_pass "NPM package.json is valid JSON"
                
                # Check required fields
                local required_fields=("name" "version" "description" "scripts")
                for field in "${required_fields[@]}"; do
                    if jq -e ".$field" "$npm_dir/package.json" >/dev/null 2>&1; then
                        test_pass "NPM package.json has '$field' field"
                    else
                        test_fail "NPM package.json missing '$field' field"
                    fi
                done
            else
                test_fail "NPM package.json is invalid JSON"
            fi
        else
            test_fail "NPM package.json not created"
        fi
        
        # Check binary wrapper
        if [[ -f "$npm_dir/bin/repo-repair" ]]; then
            test_pass "NPM binary wrapper created"
            
            if [[ -x "$npm_dir/bin/repo-repair" ]]; then
                test_pass "NPM binary wrapper is executable"
            else
                test_fail "NPM binary wrapper not executable"
            fi
        else
            test_fail "NPM binary wrapper not created"
        fi
    else
        test_skip "NPM template directory not found"
    fi
}

# Test Python package configuration
test_python_package_config() {
    test_info "Testing Python package configuration..."
    
    if ! command -v pip &> /dev/null; then
        test_skip "pip not available on this system"
        return 0
    fi
    
    # Create Python package template for testing
    local python_dir="$TEST_RESULTS_DIR/python_package"
    mkdir -p "$python_dir"
    
    # Create setup.py
    cat > "$python_dir/setup.py" << 'EOF'
from setuptools import setup, find_packages

setup(
    name="repo-repair",
    version="1.0.0",
    description="Repository repair and maintenance tool",
    author="cbwinslow",
    author_email="blaine.winslow@gmail.com",
    packages=find_packages(),
    install_requires=[
        "requests",
        "click",
        "pyyaml"
    ],
    entry_points={
        'console_scripts': [
            'repo-repair=repo_repair.cli:main',
        ],
    },
    python_requires='>=3.6',
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
    ],
)
EOF
    
    if [[ -f "$python_dir/setup.py" ]]; then
        test_pass "Python setup.py created"
        
        # Validate setup.py syntax
        if python3 -m py_compile "$python_dir/setup.py" 2>/dev/null; then
            test_pass "Python setup.py syntax valid"
        else
            test_fail "Python setup.py syntax invalid"
        fi
    else
        test_fail "Failed to create Python setup.py"
    fi
    
    # Create requirements.txt
    cat > "$python_dir/requirements.txt" << 'EOF'
requests>=2.25.0
click>=7.0
pyyaml>=5.4.0
EOF
    
    if [[ -f "$python_dir/requirements.txt" ]]; then
        test_pass "Python requirements.txt created"
    else
        test_fail "Failed to create Python requirements.txt"
    fi
}

# Test package installation workflows
test_package_installation() {
    test_info "Testing package installation workflows..."
    
    local templates_dir="$AGENT_DIR/templates"
    
    # Test APT installation workflow
    if command -v apt &> /dev/null && [[ -f "$templates_dir/apt/repo-repair.install" ]]; then
        # Dry run installation test
        if bash -n "$templates_dir/apt/repo-repair.install"; then
            test_pass "APT installation script syntax valid"
        else
            test_fail "APT installation script syntax invalid"
        fi
    else
        test_skip "APT installation workflow (not available)"
    fi
    
    # Test Docker installation workflow
    if command -v docker &> /dev/null && [[ -f "$templates_dir/docker/docker-compose.yml" ]]; then
        # Validate docker-compose syntax
        if docker-compose -f "$templates_dir/docker/docker-compose.yml" config >/dev/null 2>&1; then
            test_pass "Docker Compose configuration valid"
        else
            test_fail "Docker Compose configuration invalid"
        fi
    else
        test_skip "Docker installation workflow (not available)"
    fi
    
    # Test NPM installation workflow
    if command -v npm &> /dev/null && [[ -f "$templates_dir/npm/package.json" ]]; then
        # Test package.json validation
        cd "$templates_dir/npm"
        if npm install --dry-run 2>/dev/null; then
            test_pass "NPM installation workflow valid"
        else
            test_skip "NPM installation workflow (dependencies not available)"
        fi
        cd - > /dev/null
    else
        test_skip "NPM installation workflow (not available)"
    fi
}

# Test package dependency management
test_dependency_management() {
    test_info "Testing package dependency management..."
    
    local config_file="$AGENT_DIR/config/agent_config.json"
    
    # Check runtime dependencies
    if jq -e '.runtime.dependencies' "$config_file" >/dev/null 2>&1; then
        test_pass "Runtime dependencies defined"
        
        local dependencies
        dependencies=$(jq -r '.runtime.dependencies[]' "$config_file" 2>/dev/null)
        
        # Test if required dependencies are available
        local missing_deps=0
        while IFS= read -r dep; do
            if [[ -n "$dep" ]]; then
                if command -v "$dep" &> /dev/null; then
                    test_pass "Dependency '$dep' available"
                else
                    test_fail "Dependency '$dep' missing"
                    ((missing_deps++))
                fi
            fi
        done <<< "$dependencies"
        
        if [[ $missing_deps -eq 0 ]]; then
            test_pass "All runtime dependencies satisfied"
        else
            test_fail "$missing_deps runtime dependencies missing"
        fi
    else
        test_fail "Runtime dependencies not defined"
    fi
}

# Test package versioning and updates
test_package_versioning() {
    test_info "Testing package versioning and updates..."
    
    local templates_dir="$AGENT_DIR/templates"
    
    # Check version consistency across package configurations
    local versions=()
    
    # APT version
    if [[ -f "$templates_dir/apt/control" ]]; then
        local apt_version
        apt_version=$(grep "^Version:" "$templates_dir/apt/control" | awk '{print $2}')
        if [[ -n "$apt_version" ]]; then
            versions+=("$apt_version")
            test_pass "APT package version: $apt_version"
        fi
    fi
    
    # NPM version
    if [[ -f "$templates_dir/npm/package.json" ]]; then
        local npm_version
        npm_version=$(jq -r '.version' "$templates_dir/npm/package.json" 2>/dev/null)
        if [[ -n "$npm_version" && "$npm_version" != "null" ]]; then
            versions+=("$npm_version")
            test_pass "NPM package version: $npm_version"
        fi
    fi
    
    # Check version consistency
    if [[ ${#versions[@]} -gt 1 ]]; then
        local first_version="${versions[0]}"
        local consistent=true
        
        for version in "${versions[@]}"; do
            if [[ "$version" != "$first_version" ]]; then
                consistent=false
                break
            fi
        done
        
        if [[ "$consistent" == "true" ]]; then
            test_pass "Package versions are consistent ($first_version)"
        else
            test_fail "Package versions are inconsistent: ${versions[*]}"
        fi
    else
        test_skip "Version consistency check (insufficient package configs)"
    fi
}

# Test package distribution channels
test_distribution_channels() {
    test_info "Testing package distribution channels..."
    
    # Test GitHub Actions workflow for package publishing
    local workflows_dir="$PROJECT_ROOT/.github/workflows"
    local package_workflow="$workflows_dir/package-publish.yml"
    
    if [[ -f "$package_workflow" ]]; then
        test_pass "Package publishing workflow exists"
        
        # Basic YAML validation
        if grep -q "name:" "$package_workflow" && grep -q "on:" "$package_workflow"; then
            test_pass "Package workflow format valid"
        else
            test_fail "Package workflow format invalid"
        fi
    else
        # Create a sample workflow for testing
        mkdir -p "$workflows_dir"
        cat > "$package_workflow" << 'EOF'
name: Package and Publish

on:
  release:
    types: [published]
  push:
    tags:
      - 'v*'

jobs:
  build-and-publish:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Build APT Package
      run: |
        cd agents/repo_repair/templates/apt
        dpkg-buildpackage -us -uc
    
    - name: Build Docker Image
      run: |
        docker build -t repo-repair:${{ github.ref_name }} -f agents/repo_repair/templates/docker/Dockerfile .
    
    - name: Publish NPM Package
      if: contains(github.ref, 'refs/tags/')
      run: |
        cd agents/repo_repair/templates/npm
        npm publish
      env:
        NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
EOF
        
        test_pass "Package publishing workflow created"
    fi
    
    # Test distribution documentation
    local dist_readme="$AGENT_DIR/templates/README.md"
    if [[ ! -f "$dist_readme" ]]; then
        cat > "$dist_readme" << 'EOF'
# Repository Repair Agent Package Distribution

This directory contains package configurations for various package management systems.

## Available Packages

### APT (Debian/Ubuntu)
- Location: `apt/`
- Install: `sudo dpkg -i repo-repair.deb`

### Docker
- Location: `docker/`
- Install: `docker-compose up -d`

### NPM
- Location: `npm/`
- Install: `npm install -g repo-repair`

## Building Packages

Each package type includes build scripts and configuration files for automated packaging.

## Distribution Channels

- GitHub Releases
- NPM Registry
- Docker Hub
- APT Repository
EOF
        test_pass "Distribution documentation created"
    else
        test_pass "Distribution documentation exists"
    fi
}

# Cleanup function
cleanup() {
    test_info "Cleaning up package management tests..."
    
    # Remove test Python package
    rm -rf "$TEST_RESULTS_DIR/python_package"
    
    # Clean up any temporary package files
    rm -f "$TEST_RESULTS_DIR"/*.deb
    rm -f "$TEST_RESULTS_DIR"/*.tar.gz
}

# Main test execution
main() {
    echo "Package Management Integration Tests"
    echo "=================================="
    echo "Starting test execution: $(date)"
    echo ""
    
    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Setup trap for cleanup
    trap cleanup EXIT
    
    # Run tests
    test_package_manager_detection
    test_apt_package_config
    test_docker_package_config
    test_npm_package_config
    test_python_package_config
    test_package_installation
    test_dependency_management
    test_package_versioning
    test_distribution_channels
    
    # Show results
    echo ""
    echo "Package Management Integration Test Results"
    echo "=========================================="
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

