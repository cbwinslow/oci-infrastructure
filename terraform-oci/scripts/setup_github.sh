#!/bin/bash

# Script to prepare and upload project to GitHub
# Prerequisites: gh (GitHub CLI) must be installed and authenticated

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_NAME="cloudcurio-oracle"
REPO_DESCRIPTION="CloudCurio: Oracle Cloud Infrastructure (OCI) automation and management platform"

# Logging
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/github_setup_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to create .gitignore
create_gitignore() {
    log "Creating .gitignore file..."
    cat > "${PROJECT_ROOT}/.gitignore" << 'EOF'
# Terraform files
**/.terraform/*
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfvars
*.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# Credentials and secrets
secure/credentials/*
!secure/credentials/.gitkeep
.env
*.pem
*.key
wallet.zip
*.wallet
*.sso

# Local development
.idea/
.vscode/
*.swp
*.swo

# Logs
logs/*
!logs/.gitkeep

# System files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.bak
*.backup
EOF
    
    log ".gitignore created"
}

# Function to create GitHub-specific files
create_github_files() {
    log "Creating GitHub-specific files..."
    
    # Create README.md if it doesn't exist
    if [ ! -f "${PROJECT_ROOT}/README.md" ]; then
        cat > "${PROJECT_ROOT}/README.md" << 'EOF'
# CloudCurio Oracle

CloudCurio Oracle is a comprehensive platform for automating and managing Oracle Cloud Infrastructure (OCI) resources, with a focus on maximizing Free Tier benefits and providing enterprise-grade management capabilities.

## Features

- Complete Free Tier deployment
- Secure credential management
- Monitoring and alerting
- Automated testing
- Security compliance checks

## Prerequisites

- OCI Free Tier Account
- Terraform installed
- OCI CLI configured
- GitHub CLI (gh) installed

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/cbwinslow/cloudcurio-oracle.git
   cd cloudcurio-oracle
   ```

2. Initialize secure storage:
   ```bash
   ./scripts/init_secure_storage.sh
   ```

3. Store credentials:
   ```bash
   ./scripts/manage_credentials.sh store
   ```

4. Deploy infrastructure:
   ```bash
   ./scripts/deploy_free_tier.sh
   ```

## Documentation

Detailed documentation is available in the [docs](docs/) directory.

## Security

This project implements several security best practices:
- Encrypted credential storage
- Security compliance checks
- Access control
- Regular auditing

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
EOF
    fi
    
    # Create CONTRIBUTING.md
    cat > "${PROJECT_ROOT}/CONTRIBUTING.md" << 'EOF'
# Contributing to OCI Free Tier Infrastructure

We love your input! We want to make contributing as easy and transparent as possible.

## Development Process

1. Fork the repo
2. Clone it and install dependencies
3. Create a new branch
4. Make your changes
5. Submit a pull request

## Pull Request Process

1. Update the README.md with details of changes
2. Update the documentation
3. Test your changes
4. Submit the pull request

## Any contributions you make will be under the MIT Software License

When you submit code changes, your submissions are understood to be under the same [MIT License](LICENSE) that covers the project.
EOF
    
    # Create LICENSE
    cat > "${PROJECT_ROOT}/LICENSE" << 'EOF'
MIT License

Copyright (c) 2025 Blaine Winslow

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
    
    log "GitHub files created"
}

# Function to initialize git repository
init_git() {
    log "Initializing git repository..."
    
    cd "$PROJECT_ROOT"
    
    # Initialize git if not already initialized
    if [ ! -d ".git" ]; then
        git init
        log "Git repository initialized"
    else
        log "Git repository already initialized"
    fi
    
    # Add files and create initial commit
    git add .
    git commit -m "Initial commit: CloudCurio Oracle Platform"
}

# Function to create and push to GitHub
create_github_repo() {
    log "Creating GitHub repository..."
    
    # Check if gh is installed and authenticated
    if ! command -v gh &> /dev/null; then
        log "Error: GitHub CLI (gh) is not installed"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log "Error: GitHub CLI is not authenticated"
        exit 1
    }
    
    # Create repository
    gh repo create "$REPO_NAME" \
        --description "$REPO_DESCRIPTION" \
        --public \
        --source="$PROJECT_ROOT" \
        --remote=origin
    
    # Push to GitHub
    git push -u origin main
    
    log "Repository created and code pushed to GitHub"
    
    # Enable GitHub features
    gh repo edit "$REPO_NAME" \
        --enable-issues \
        --enable-wiki \
        --enable-projects
    
    log "GitHub features enabled"
}

# Function to set up GitHub Actions
setup_github_actions() {
    log "Setting up GitHub Actions..."
    
    mkdir -p "${PROJECT_ROOT}/.github/workflows"
    
    # Create main workflow
    cat > "${PROJECT_ROOT}/.github/workflows/main.yml" << 'EOF'
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v1
    
    - name: Terraform Format
      run: terraform fmt -check
    
    - name: Terraform Init
      run: terraform init
    
    - name: Terraform Validate
      run: terraform validate

  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Run Security Checks
      run: |
        chmod +x ./scripts/audit_security.sh
        ./scripts/audit_security.sh

  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Run Tests
      run: |
        chmod +x ./tests/infrastructure_test.sh
        ./tests/infrastructure_test.sh
EOF
    
    git add .github/workflows/main.yml
    git commit -m "Add GitHub Actions workflow"
    git push
    
    log "GitHub Actions configured"
}

# Function to create initial issues
create_initial_issues() {
    log "Creating initial issues..."
    
    # Create issues
    gh issue create \
        --title "Implement cost optimization" \
        --body "Add cost optimization features including budget alerts and resource usage tracking."
    
    gh issue create \
        --title "Add performance benchmarking" \
        --body "Implement performance benchmarking and monitoring system."
    
    gh issue create \
        --title "Enhance security monitoring" \
        --body "Add additional security monitoring and compliance checks."
    
    gh issue create \
        --title "Expand test coverage" \
        --body "Add more comprehensive tests for infrastructure components."
    
    log "Initial issues created"
}

# Main function
main() {
    log "Starting GitHub repository setup..."
    
    create_gitignore
    create_github_files
    init_git
    create_github_repo
    setup_github_actions
    create_initial_issues
    
    log "GitHub repository setup completed!"
    echo "Repository URL: https://github.com/cbwinslow/$REPO_NAME"
}

# Run main function
main "$@"

