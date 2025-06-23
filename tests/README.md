# Repository Repair Agent Test Suite

This comprehensive test suite validates the functionality of the Repository Repair Agent across multiple dimensions including core functionality, integration capabilities, and security compliance.

## Overview

The test suite consists of:

1. **Core functionality tests** - Permission fixes, repository sync, and rollback functionality
2. **Integration tests** - AI agent framework, package management, and security tools
3. **Comprehensive reporting** - HTML reports, JSON summaries, and detailed logs

## Test Structure

```
tests/
├── test_suite.sh                 # Main test suite with core functionality
├── run_all_tests.sh              # Master test runner
├── integration/                  # Integration test suites
│   ├── test_ai_framework.sh      # AI agent framework integration
│   ├── test_package_management.sh # Package management integration
│   └── test_security_tools.sh    # Security tools integration
├── results/                      # Generated test results and reports
│   ├── comprehensive_test_report.html
│   ├── test_summary.json
│   ├── individual_reports/
│   └── artifacts/
└── README.md                     # This file
```

## Quick Start

### Run All Tests
```bash
cd tests
./run_all_tests.sh
```

### Run Specific Test Suite
```bash
# Core functionality only
./test_suite.sh

# Specific test category
./test_suite.sh --test-suite permissions
./test_suite.sh --test-suite sync  
./test_suite.sh --test-suite rollback

# Integration tests
./integration/test_ai_framework.sh
./integration/test_package_management.sh
./integration/test_security_tools.sh
```

### Run with Options
```bash
# Verbose output
./test_suite.sh --verbose

# Skip cleanup (preserve test data)
./test_suite.sh --no-cleanup

# Generate archive for results
./run_all_tests.sh --upload-results
```

## Test Categories

### 1. Core Functionality Tests (`test_suite.sh`)

#### Permission Tests (`test_permissions()`)
- ✅ Permission fix script existence and syntax
- ✅ Permission issue detection
- ✅ Dry-run functionality
- ✅ Actual permission fixing
- ✅ Ownership fixing (if running as root)

**Test Implementation:**
```bash
test_permissions() {
    # Test permission fixes
    local test_repo="$TEST_DATA_DIR/broken_repo"
    local fix_script="$AGENT_DIR/scripts/fix_permissions.sh"
    
    # Create script if missing
    if [[ ! -f "$fix_script" ]]; then
        create_fix_permissions_script
    fi
    
    # Test execution and validation
    bash "$fix_script" --target-path="$test_repo" --dry-run
    bash "$fix_script" --target-path="$test_repo" --fix-executable=true
}
```

#### Sync Tests (`test_sync()`)
- ✅ Repository sync script functionality
- ✅ Git status checking
- ✅ Local changes detection
- ✅ Dry-run capability
- ✅ Branch-specific synchronization

**Test Implementation:**
```bash
test_sync() {
    # Test repository sync
    local test_repo="$TEST_DATA_DIR/test_repo"
    local sync_script="$AGENT_DIR/scripts/sync_repos.sh"
    
    # Test various sync scenarios
    bash "$sync_script" --repo-path="$test_repo" --dry-run
    bash "$sync_script" --repo-path="$test_repo" --branch="test-branch"
}
```

#### Rollback Tests (`test_rollback()`)
- ✅ Rollback script functionality
- ✅ Backup creation and restoration
- ✅ Git-based rollback to specific commits
- ✅ Dry-run validation

**Test Implementation:**
```bash
test_rollback() {
    # Test rollback functionality
    local test_repo="$TEST_DATA_DIR/test_repo"
    local rollback_script="$AGENT_DIR/scripts/rollback.sh"
    
    # Test rollback scenarios
    bash "$rollback_script" --repo-path="$test_repo" --target="HEAD~1" --dry-run
    bash "$rollback_script" --repo-path="$test_repo" --restore-backup="$backup_dir"
}
```

### 2. Integration Tests

#### AI Agent Framework Integration (`test_ai_framework.sh`)
- ✅ Agent registration with mock AI framework
- ✅ Capabilities reporting and validation
- ✅ Health check endpoints
- ✅ Communication protocols (HTTP/JSON)
- ✅ Error handling and recovery
- ✅ Service discovery and monitoring
- ✅ Workflow orchestration

**Features:**
- Mock AI framework server for testing
- Complete registration workflow simulation
- Configuration validation
- Protocol compliance testing

#### Package Management Integration (`test_package_management.sh`)
- ✅ Package manager detection (apt, npm, docker, pip, etc.)
- ✅ APT package configuration and validation
- ✅ Docker container packaging
- ✅ NPM package.json generation
- ✅ Python setuptools integration
- ✅ Installation workflow testing
- ✅ Dependency management
- ✅ Version consistency across packages

**Supported Package Managers:**
- **APT** (Debian/Ubuntu): Control files, install scripts
- **Docker**: Dockerfile, docker-compose.yml
- **NPM**: package.json, binary wrappers
- **Python**: setup.py, requirements.txt

#### Security Tools Integration (`test_security_tools.sh`)
- ✅ Static code analysis (ShellCheck)
- ✅ Secrets scanning with pattern matching
- ✅ Dependency vulnerability scanning
- ✅ Container security analysis
- ✅ Security configuration validation
- ✅ Monitoring and alerting setup
- ✅ Compliance standards checking
- ✅ Incident response capabilities

**Security Standards Covered:**
- OWASP Top 10 compliance checks
- CIS Controls validation
- Container security best practices
- Secrets management verification

## Test Requirements

### System Dependencies
```bash
# Required tools
sudo apt-get install -y git jq curl bash

# Optional but recommended
sudo apt-get install -y shellcheck docker.io nodejs npm python3-pip

# For AI framework testing
python3 -m pip install --user requests
```

### Environment Setup
```bash
# Ensure proper permissions
chmod +x tests/*.sh tests/integration/*.sh

# Set up git configuration for testing
git config --global user.email "test@example.com"
git config --global user.name "Test User"
```

## Test Reports

The test suite generates comprehensive reports in multiple formats:

### HTML Report (`comprehensive_test_report.html`)
- Interactive dashboard with test results
- Suite-by-suite breakdown
- Environment information
- Expandable log sections
- Visual progress indicators

### JSON Summary (`test_summary.json`)
```json
{
  "test_run": {
    "start_time": "2024-01-15 10:30:00",
    "end_time": "2024-01-15 10:35:22", 
    "duration": "322s",
    "total_suites": 4,
    "passed_suites": 4,
    "failed_suites": 0,
    "suite_results": {...}
  }
}
```

### Individual Suite Reports
- Detailed logs for each test suite
- Pass/fail statistics
- Execution duration
- Error details and troubleshooting info

## Test Data Management

### Temporary Test Data
- Created in `tests/test_data/` directory
- Includes mock repositories with various states
- Automatically cleaned up unless `--no-cleanup` is used

### Backup and Restore
- Original configurations backed up before testing
- Automatic restoration after test completion
- Preservation of test artifacts for debugging

## Continuous Integration

### GitHub Actions Integration
```yaml
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run Tests
      run: |
        cd tests
        ./run_all_tests.sh
    - name: Upload Results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: tests/results/
```

### Local Development Workflow
```bash
# Quick validation during development
./test_suite.sh --test-suite permissions

# Full regression testing
./run_all_tests.sh

# Debug specific failures
./test_suite.sh --verbose --no-cleanup
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   ```bash
   chmod +x tests/*.sh tests/integration/*.sh
   ```

2. **Missing Dependencies**
   ```bash
   # Check what's available
   ./run_all_tests.sh
   # Review environment_info.txt for missing tools
   ```

3. **Test Failures**
   ```bash
   # Check individual suite logs
   cat tests/results/individual_reports/main_suite.log
   
   # Run with verbose output
   ./test_suite.sh --verbose
   ```

4. **Mock Services Not Starting**
   ```bash
   # Check port availability
   netstat -an | grep :8080
   
   # Ensure Python is available for mock servers
   python3 --version
   ```

### Debug Mode
```bash
# Enable bash debugging
bash -x ./test_suite.sh --test-suite permissions

# Preserve test environment
./test_suite.sh --no-cleanup
ls tests/test_data/  # Examine test artifacts
```

## Contributing

### Adding New Tests

1. **Core Functionality Tests**
   - Add new test functions to `test_suite.sh`
   - Follow naming convention: `test_<functionality>()`
   - Include all test result functions: `test_pass`, `test_fail`, `test_skip`

2. **Integration Tests**
   - Create new files in `integration/` directory
   - Follow existing template structure
   - Include proper cleanup functions

3. **Test Categories**
   ```bash
   # Add to main test suite selection
   case "$test_suite" in
       "new_category")
           test_new_functionality
           ;;
   esac
   ```

### Test Quality Standards

- ✅ Each test must be independent and idempotent
- ✅ Proper error handling with meaningful messages
- ✅ Cleanup of temporary resources
- ✅ Clear documentation of test purpose
- ✅ Consistent naming and structure

### Code Review Checklist

- [ ] Test covers happy path and error conditions
- [ ] Appropriate use of test_pass/fail/skip functions
- [ ] Proper cleanup in case of failures
- [ ] Documentation updated
- [ ] Integration with master test runner

## Performance Considerations

### Test Execution Times
- Core functionality tests: ~30-60 seconds
- Integration tests: ~60-120 seconds each
- Full suite: ~5-10 minutes

### Resource Usage
- Temporary disk space: ~100MB
- Memory usage: <256MB
- Network: Only for mock server testing

### Optimization Tips
```bash
# Run specific categories for faster feedback
./test_suite.sh --test-suite permissions

# Skip report generation for speed
./run_all_tests.sh --no-reports

# Parallel execution (experimental)
./run_all_tests.sh --parallel
```

## Security Considerations

### Test Isolation
- Tests run in isolated temporary directories
- No modification of system-level configurations
- Safe to run on development machines

### Sensitive Data
- No real credentials used in tests
- Mock services for external integrations
- Test data automatically cleaned up

### Sandboxing
- Tests respect configured security boundaries
- Container-based isolation when Docker is available
- Permission validation without system-level changes

---

## Support

For issues with the test suite:

1. Check the troubleshooting section above
2. Review generated test reports in `tests/results/`
3. Run with `--verbose` flag for detailed output
4. Create GitHub issues with:
   - Test failure details
   - Environment information
   - Generated reports

## License

This test suite is part of the Repository Repair Agent project and follows the same licensing terms.

