#!/bin/bash

# Script to set up additional GitHub features

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GITHUB_DIR="${PROJECT_ROOT}/.github"

# Create directories
mkdir -p "${GITHUB_DIR}/ISSUE_TEMPLATE"
mkdir -p "${GITHUB_DIR}/PULL_REQUEST_TEMPLATE"
mkdir -p "${GITHUB_DIR}/workflows"

# Function to set up issue templates
setup_issue_templates() {
    # Bug report template
    cat > "${GITHUB_DIR}/ISSUE_TEMPLATE/bug_report.yml" << 'EOF'
name: Bug Report
description: File a bug report
title: "[Bug]: "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  - type: input
    id: version
    attributes:
      label: Version
      description: What version of CloudCurio are you running?
    validations:
      required: true
  - type: dropdown
    id: environment
    attributes:
      label: Environment
      options:
        - Production
        - Staging
        - Development
    validations:
      required: true
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Also tell us, what did you expect to happen?
    validations:
      required: true
  - type: textarea
    id: logs
    attributes:
      label: Relevant log output
      description: Please copy and paste any relevant log output
      render: shell
EOF

    # Feature request template
    cat > "${GITHUB_DIR}/ISSUE_TEMPLATE/feature_request.yml" << 'EOF'
name: Feature Request
description: Suggest an idea for this project
title: "[Feature]: "
labels: ["enhancement"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to suggest a new feature!
  - type: textarea
    id: problem
    attributes:
      label: Problem Statement
      description: Is your feature request related to a problem? Please describe.
    validations:
      required: true
  - type: textarea
    id: solution
    attributes:
      label: Proposed Solution
      description: Describe the solution you'd like
    validations:
      required: true
  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives Considered
      description: Describe any alternative solutions you've considered
  - type: checkboxes
    id: terms
    attributes:
      label: Code of Conduct
      description: By submitting this issue, you agree to follow our Code of Conduct
      options:
        - label: I agree to follow this project's Code of Conduct
          required: true
EOF
}

# Function to set up pull request template
setup_pr_template() {
    cat > "${GITHUB_DIR}/PULL_REQUEST_TEMPLATE/pull_request_template.md" << 'EOF'
## Description
Please include a summary of the change and which issue is fixed. Include relevant motivation and context.

Fixes # (issue)

## Type of change
Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

## How Has This Been Tested?
Please describe the tests that you ran to verify your changes.

- [ ] Test A
- [ ] Test B

## Checklist:
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published in downstream modules
EOF
}

# Function to set up security policy
setup_security_policy() {
    cat > "${PROJECT_ROOT}/SECURITY.md" << 'EOF'
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

Please report security vulnerabilities by:

1. Opening a [private security advisory](https://github.com/cbwinslow/cloudcurio-oracle/security/advisories/new)
2. Emailing security@cloudcurio.com

We will acknowledge receipt within 24 hours and provide a detailed response within 48 hours.

## Security Measures

- All code is scanned for vulnerabilities using:
  - Snyk
  - SonarQube
  - GitHub CodeQL
  - Trivy

- Infrastructure is monitored using:
  - OCI Security Advisor
  - Datadog Security Monitoring
  - PagerDuty alerts

## Disclosure Policy

When we receive a security bug report, we will:

1. Confirm the problem and determine affected versions
2. Audit code for similar problems
3. Prepare fixes for all supported versions
4. Release new versions and patches
EOF
}

# Function to set up code of conduct
setup_code_of_conduct() {
    cat > "${PROJECT_ROOT}/CODE_OF_CONDUCT.md" << 'EOF'
# Contributor Covenant Code of Conduct

## Our Pledge

We as members, contributors, and leaders pledge to make participation in our
community a harassment-free experience for everyone.

## Our Standards

Examples of behavior that contributes to a positive environment:

* Demonstrating empathy and kindness toward other people
* Being respectful of differing opinions, viewpoints, and experiences
* Giving and gracefully accepting constructive feedback
* Accepting responsibility and apologizing to those affected by our mistakes
* Focusing on what is best for the overall community

## Enforcement Responsibilities

Community leaders are responsible for clarifying and enforcing our standards of
acceptable behavior and will take appropriate and fair corrective action in
response to any behavior that they deem inappropriate, threatening, offensive,
or harmful.

## Scope

This Code of Conduct applies within all community spaces, and also applies when
an individual is officially representing the community in public spaces.

## Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be
reported to the community leaders responsible for enforcement at
conduct@cloudcurio.com.

## Attribution

This Code of Conduct is adapted from the [Contributor Covenant][homepage],
version 2.0, available at
https://www.contributor-covenant.org/version/2/0/code_of_conduct.html.
EOF
}

# Function to set up discussion categories
setup_discussions() {
    gh api \
        --method POST \
        -H "Accept: application/vnd.github.v3+json" \
        "/repos/cbwinslow/cloudcurio-oracle/discussions/categories" \
        -f name='Announcements' \
        -f description='Official announcements about CloudCurio Oracle' \
        -f emoji=':mega:'

    gh api \
        --method POST \
        -H "Accept: application/vnd.github.v3+json" \
        "/repos/cbwinslow/cloudcurio-oracle/discussions/categories" \
        -f name='Ideas' \
        -f description='Ideas for new features or improvements' \
        -f emoji=':bulb:'

    gh api \
        --method POST \
        -H "Accept: application/vnd.github.v3+json" \
        "/repos/cbwinslow/cloudcurio-oracle/discussions/categories" \
        -f name='Q&A' \
        -f description='Ask questions and get help from the community' \
        -f emoji=':question:'
}

# Function to set up project labels
setup_labels() {
    # Remove default labels
    gh api \
        --method DELETE \
        "/repos/cbwinslow/cloudcurio-oracle/labels/bug" || true
    
    # Create custom labels
    gh api \
        --method POST \
        "/repos/cbwinslow/cloudcurio-oracle/labels" \
        -f name='bug:critical' \
        -f color='b60205' \
        -f description='Critical bugs that need immediate attention'

    gh api \
        --method POST \
        "/repos/cbwinslow/cloudcurio-oracle/labels" \
        -f name='feature:core' \
        -f color='0e8a16' \
        -f description='Core feature implementations'

    gh api \
        --method POST \
        "/repos/cbwinslow/cloudcurio-oracle/labels" \
        -f name='security' \
        -f color='d93f0b' \
        -f description='Security-related changes'

    gh api \
        --method POST \
        "/repos/cbwinslow/cloudcurio-oracle/labels" \
        -f name='documentation' \
        -f color='0075ca' \
        -f description='Documentation improvements'
}

# Function to set up branch protection rules
setup_branch_rules() {
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github.v3+json" \
        "/repos/cbwinslow/cloudcurio-oracle/branches/main/protection" \
        -f required_status_checks='{"strict":true,"contexts":["tests","security"]}' \
        -f enforce_admins=true \
        -f required_pull_request_reviews='{"dismissal_restrictions":{},"dismiss_stale_reviews":true,"require_code_owner_reviews":true,"required_approving_review_count":1}' \
        -f restrictions=null

    gh api \
        --method PUT \
        -H "Accept: application/vnd.github.v3+json" \
        "/repos/cbwinslow/cloudcurio-oracle/branches/main/protection/required_signatures" \
        -f enabled=true
}

# Function to set up repository settings
setup_repo_settings() {
    gh api \
        --method PATCH \
        "/repos/cbwinslow/cloudcurio-oracle" \
        -f has_issues=true \
        -f has_projects=true \
        -f has_wiki=true \
        -f has_downloads=true \
        -f allow_squash_merge=true \
        -f allow_merge_commit=false \
        -f allow_rebase_merge=true \
        -f delete_branch_on_merge=true \
        -f allow_auto_merge=true
}

# Main function
main() {
    echo "Setting up additional GitHub features..."
    
    setup_issue_templates
    setup_pr_template
    setup_security_policy
    setup_code_of_conduct
    setup_discussions
    setup_labels
    setup_branch_rules
    setup_repo_settings
    
    echo "GitHub features setup completed!"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

