#!/bin/bash

# Enhanced GitHub setup script with additional features and integrations

source $(dirname "$0")/setup_github.sh

# Function to set up GitHub project boards
setup_project_boards() {
    log "Setting up project boards..."
    
    # Create main project board
    gh project create "CloudCurio Development" \
        --org cbwinslow \
        --public
    
    # Create columns
    gh project-column create "To Do"
    gh project-column create "In Progress"
    gh project-column create "Review"
    gh project-column create "Done"
    
    log "Project boards created"
}

# Function to set up branch protection
setup_branch_protection() {
    log "Setting up branch protection rules..."
    
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github.v3+json" \
        "/repos/cbwinslow/$REPO_NAME/branches/main/protection" \
        -f required_status_checks='{"strict":true,"contexts":["tests"]}' \
        -f enforce_admins=true \
        -f required_pull_request_reviews='{"dismissal_restrictions":{},"dismiss_stale_reviews":true,"require_code_owner_reviews":true}' \
        -f restrictions=null
    
    log "Branch protection rules configured"
}

# Function to create additional workflows
create_additional_workflows() {
    log "Creating additional GitHub Actions workflows..."
    
    # Create security scanning workflow
    cat > "${PROJECT_ROOT}/.github/workflows/security.yml" << 'EOF'
name: Security Scanning

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * *'

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        ignore-unfixed: true
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Run tfsec
      uses: tfsec/tfsec-sarif-action@main
      with:
        sarif_file: tfsec.sarif
    
    - name: Upload SARIF file
      uses: github/codeql-action/upload-sarif@v1
      with:
        sarif_file: tfsec.sarif
EOF

    # Create documentation workflow
    cat > "${PROJECT_ROOT}/.github/workflows/docs.yml" << 'EOF'
name: Documentation

on:
  push:
    branches: [ main ]
    paths:
      - 'docs/**'
      - '**.md'

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.x'
    
    - name: Install dependencies
      run: |
        pip install mkdocs mkdocs-material
    
    - name: Build documentation
      run: mkdocs build
    
    - name: Deploy to GitHub Pages
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./site
EOF

    log "Additional workflows created"
}

# Function to set up additional integrations
setup_integrations() {
    log "Setting up additional integrations..."
    
    # Add Dependabot configuration
    mkdir -p "${PROJECT_ROOT}/.github"
    cat > "${PROJECT_ROOT}/.github/dependabot.yml" << 'EOF'
version: 2
updates:
  - package-ecosystem: "terraform"
    directory: "/"
    schedule:
      interval: "daily"
    labels:
      - "terraform"
      - "dependencies"
  
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "ci"
      - "dependencies"
EOF

    # Add CodeQL configuration
    cat > "${PROJECT_ROOT}/.github/codeql-config.yml" << 'EOF'
name: "CodeQL config"
queries:
  - uses: security-extended
  - uses: security-and-quality
EOF

    log "Integrations configured"
}

# Function to create additional issues
create_additional_issues() {
    log "Creating additional issues..."
    
    # Development issues
    gh issue create \
        --title "Implement CloudCurio CLI tool" \
        --body "Create a command-line interface for CloudCurio Oracle with common management commands."
    
    gh issue create \
        --title "Add infrastructure drift detection" \
        --body "Implement automated detection and notification of infrastructure drift."
    
    # Documentation issues
    gh issue create \
        --title "Create architecture decision records (ADRs)" \
        --body "Document key architectural decisions and their rationale."
    
    gh issue create \
        --title "Add troubleshooting guide" \
        --body "Create comprehensive troubleshooting documentation with common issues and solutions."
    
    # Security issues
    gh issue create \
        --title "Implement security scanning pipeline" \
        --body "Add automated security scanning for infrastructure code and dependencies."
    
    gh issue create \
        --title "Add compliance reporting" \
        --body "Implement automated compliance reporting for common standards (CIS, SOC2, etc.)."
    
    # Feature issues
    gh issue create \
        --title "Add multi-region support" \
        --body "Implement support for managing resources across multiple OCI regions."
    
    gh issue create \
        --title "Create resource tagging system" \
        --body "Implement comprehensive resource tagging system with enforcement and reporting."
    
    # Integration issues
    gh issue create \
        --title "Add Slack integration" \
        --body "Implement Slack notifications for important events and alerts."
    
    gh issue create \
        --title "Create Grafana dashboards" \
        --body "Develop Grafana dashboards for monitoring and visualization."
    
    log "Additional issues created"
}

# Enhanced main function
main_enhanced() {
    main "$@"
    
    log "Setting up enhanced features..."
    
    setup_project_boards
    setup_branch_protection
    create_additional_workflows
    setup_integrations
    create_additional_issues
    
    log "Enhanced setup completed!"
}

# Run enhanced setup if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_enhanced "$@"
fi

