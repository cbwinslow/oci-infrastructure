# Project Tracking System

## Overview
This document outlines the comprehensive project tracking system implemented for the OCI Infrastructure project, integrating GitHub Issues, project boards, CI/CD status tracking, and external tool integrations.

## Project Board Structure

### Columns
1. **Backlog** - New issues and planned work
2. **In Progress** - Currently active work items
3. **Review** - Items awaiting review or approval
4. **Done** - Completed work items

### Labels
- `bug` - Bug reports and fixes
- `feature-request` - New feature requests
- `documentation` - Documentation tasks
- `security` - Security improvements
- `template` - Template issues for reference
- `in-progress` - Currently being worked on
- `review` - Ready for review

## Issue Templates

### 🐛 Bug Tracking Template
Use for reporting bugs and issues. Includes:
- Description and reproduction steps
- Expected vs actual behavior
- Environment details
- Priority level

**GitHub Issue:** [#1](https://github.com/cbwinslow/oci-infrastructure/issues/1)

### ✨ Feature Request Template
Use for proposing new features. Includes:
- Problem description
- Proposed solution
- Implementation notes
- Priority and effort estimation

**GitHub Issue:** [#2](https://github.com/cbwinslow/oci-infrastructure/issues/2)

### 📚 Documentation Task Template
Use for documentation work. Includes:
- Documentation type
- Current state and desired outcome
- Acceptance criteria
- Files to update

**GitHub Issue:** [#3](https://github.com/cbwinslow/oci-infrastructure/issues/3)

### 🔒 Security Improvement Template
Use for security-related work. Includes:
- Security category
- Risk level assessment
- Impact analysis
- Compliance requirements

**GitHub Issue:** [#4](https://github.com/cbwinslow/oci-infrastructure/issues/4)

## Active Issues

### Current Bugs
- [#5: Terraform log files accumulating in logs directory](https://github.com/cbwinslow/oci-infrastructure/issues/5)

### Current Features
- [#6: Add JIRA integration for project tracking](https://github.com/cbwinslow/oci-infrastructure/issues/6)

### Current Documentation
- [#7: Update SRS.md with current project requirements](https://github.com/cbwinslow/oci-infrastructure/issues/7)

### Current Security
- [#8: Implement secrets management and credential rotation](https://github.com/cbwinslow/oci-infrastructure/issues/8)

## CI/CD Integration

### GitHub Actions Workflow
The project includes automated CI/CD integration via `.github/workflows/project-tracking.yml`:

#### Features:
1. **Automatic Labeling** - Issues are automatically labeled based on title patterns
2. **JIRA Synchronization** - Placeholder for JIRA integration (requires API setup)
3. **Monitoring Alerts** - Automated health checks every 4 hours
4. **CI/CD Status Updates** - Terraform validation and status reporting

#### Triggers:
- Issue events (opened, closed, edited, labeled)
- Pull request events
- Push to main/develop branches
- Scheduled monitoring (every 4 hours)

## JIRA Integration

### Setup Requirements
To enable JIRA integration, configure the following:

#### Method 1: Automated Setup (Recommended)
```bash
# Run the interactive setup script
./scripts/setup-jira-integration.sh
```

#### Method 2: Manual Configuration
1. **Edit Environment File**
   ```bash
   # Edit .env.jira file
   nano .env.jira
   
   # Configure your JIRA settings:
   export JIRA_BASE_URL="https://cloudcurio.atlassian.net"
   export JIRA_EMAIL="blaine.winslow@gmail.com"
   export JIRA_API_TOKEN="your-api-token"
   export JIRA_PROJECT_KEY="OCIINFRA"
   export GITHUB_REPOSITORY="cbwinslow/oci-infrastructure"
   ```

2. **Test Configuration**
   ```bash
   # Load environment variables
   source .env.jira
   
   # Test connection
   ./scripts/jira-integration.sh test
   
   # Sync existing issues
   ./scripts/jira-integration.sh sync
   ```

2. **Webhook Configuration**
   - GitHub → JIRA: Issue creation/updates
   - JIRA → GitHub: Status synchronization

3. **Field Mapping**
   - GitHub Labels → JIRA Issue Types
   - GitHub Milestones → JIRA Epics
   - GitHub Assignees → JIRA Assignees

### Integration Features
- **Bidirectional Sync** - Changes in either system reflect in the other
- **Automated Ticket Creation** - GitHub issues automatically create JIRA tickets
- **Status Mapping** - GitHub issue states map to JIRA workflow states
- **Comment Synchronization** - Comments sync between platforms

## Monitoring and Alerts

### Automated Monitoring
The system monitors:
- Log file accumulation
- Uncommitted changes
- Security vulnerabilities
- Infrastructure health
- CI/CD pipeline status

### Alert Types
- **Warning** - Non-critical issues requiring attention
- **Error** - Critical issues requiring immediate action
- **Info** - Status updates and notifications

### Monitoring Schedule
- **Infrastructure Health**: Every 4 hours
- **Security Scans**: Daily
- **Dependency Checks**: Weekly
- **Performance Metrics**: Continuous

## External Tool Integrations

### Planned Integrations
1. **JIRA** - Project management and issue tracking
2. **Slack/Teams** - Notifications and alerts
3. **Monitoring Tools** - Grafana, Prometheus integration
4. **Security Tools** - SAST/DAST integration
5. **Documentation** - Confluence integration

### Integration Architecture
```
GitHub Issues → GitHub Actions → External APIs
     ↓               ↓              ↓
Project Board → CI/CD Pipeline → Monitoring
     ↓               ↓              ↓
  Reporting → Status Updates → Notifications
```

## Usage Guidelines

### Creating Issues
1. Use appropriate templates for different issue types
2. Add relevant labels for automatic categorization
3. Assign to team members when applicable
4. Link to related issues or pull requests

### Project Board Management
1. Move issues through columns based on progress
2. Update labels to reflect current status
3. Use milestones for sprint/release planning
4. Regular grooming and prioritization

### CI/CD Integration
1. All commits trigger validation workflows
2. Issues are automatically updated with CI/CD status
3. Failed builds create notifications
4. Security scans run on schedule

## Metrics and Reporting

### Key Metrics
- Issue resolution time
- Bug discovery rate
- Feature delivery velocity
- Security vulnerability count
- Documentation coverage

### Reports
- Weekly status reports
- Monthly trend analysis
- Quarterly security assessments
- Annual project reviews

## Best Practices

### Issue Management
- Use descriptive titles with emoji indicators
- Provide detailed descriptions and acceptance criteria
- Regular triage and prioritization
- Link related issues and dependencies

### Documentation
- Keep templates updated
- Document workflow changes
- Maintain integration guides
- Regular documentation reviews

### Security
- Regular security scans
- Vulnerability tracking and remediation
- Access control reviews
- Compliance monitoring

## Troubleshooting

### Common Issues
1. **JIRA Sync Failures** - Check API credentials and network connectivity
2. **Missing Labels** - Ensure labels are created before assignment
3. **Workflow Failures** - Review GitHub Actions logs
4. **Permission Issues** - Verify GitHub and JIRA permissions

### Support
- GitHub Issues for bug reports
- Documentation for setup guides
- Team lead for integration questions
- Security team for compliance issues

## Future Enhancements

### Planned Features
- Advanced project analytics
- Automated testing integration
- Enhanced security scanning
- Mobile notifications
- AI-powered issue categorization

### Roadmap
- Q1: JIRA integration completion
- Q2: Advanced monitoring implementation
- Q3: Mobile app integration
- Q4: AI/ML enhancements

