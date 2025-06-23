# Repository Repair Agent - Infrastructure Integration

## Overview

The Repository Repair Agent is a comprehensive tool designed to integrate with existing infrastructure, providing automated repository maintenance, permission fixes, and synchronization capabilities. This document outlines the integration with AI agent frameworks and package management systems.

## Features

### Core Capabilities
- **fix_permissions**: Automated file and directory permission repair
- **sync_repos**: Repository synchronization with remote origins
- **handle_changes**: Change management and conflict resolution

### AI Agent Integration
- Registers with AI agent frameworks using standardized APIs
- Provides comprehensive capability definitions and workflows
- Supports health monitoring and metrics collection
- Includes security sandbox and permission controls

### Package Management Integration
- **APT/DEB packages**: Native Debian/Ubuntu package support
- **Docker containers**: Containerized deployment options
- **NPM packages**: Node.js ecosystem integration
- **SystemD services**: Linux service management

## Architecture

```
agents/repo_repair/
├── register_agent.sh          # Main AI framework registration script
├── config/
│   ├── agent_config.json      # Agent configuration and metadata
│   ├── capabilities.json      # Capability definitions and workflows
│   └── service_config.json    # Generated service configuration
├── scripts/
│   ├── deploy.sh             # Complete deployment and installation
│   ├── package_integration.sh # Package management integration
│   └── [capability scripts]  # Individual capability implementations
└── templates/
    ├── apt/                  # APT package templates
    ├── docker/               # Docker deployment templates
    ├── npm/                  # NPM package templates
    └── triggers/             # Automated trigger configurations
```

## Installation

### Quick Installation

```bash
# Clone the repository
git clone https://github.com/cbwinslow/oci-infrastructure.git
cd oci-infrastructure/agents/repo_repair

# Run the deployment script
sudo ./scripts/deploy.sh
```

### Custom Installation

```bash
# Custom installation directory and service user
sudo ./scripts/deploy.sh \
    --install-dir /opt/repo-repair \
    --service-user repo-repair \
    --ai-endpoint http://ai-framework:8080/api/v1
```

### Dry Run (Preview Changes)

```bash
# See what would be installed without making changes
./scripts/deploy.sh --dry-run
```

## Configuration

### Environment Variables

```bash
# AI Framework Configuration
AI_FRAMEWORK_ENDPOINT=http://localhost:8080/api/v1
AI_FRAMEWORK_TOKEN=your_token_here

# Agent Configuration
REPO_REPAIR_LOG_LEVEL=INFO
REPO_REPAIR_TIMEOUT=300
REPO_REPAIR_MAX_RETRIES=3

# Service Configuration
REPO_REPAIR_PORT=8081
REPO_REPAIR_HOST=0.0.0.0
```

### AI Framework Registration

The agent automatically registers with the AI framework using the provided configuration:

```bash
# Register with AI framework
register_tool "repo_repair" {
    capabilities = ["fix_permissions", "sync_repos", "handle_changes"]
    documentation = "Repository repair and maintenance tool"
}
```

### Package Integration

The tool supports multiple package management systems:

#### APT/DEB Package
```bash
# Install via APT (when package is published)
sudo apt install repo-repair

# Or build from source
cd templates/apt
dpkg-deb --build . repo-repair.deb
sudo dpkg -i repo-repair.deb
```

#### Docker Container
```bash
# Build and run with Docker
cd templates/docker
docker build -t repo-repair-agent .
docker run -d -p 8081:8081 repo-repair-agent

# Or use Docker Compose
docker-compose up -d
```

#### NPM Package
```bash
# Install globally via NPM (when published)
npm install -g repo-repair-agent

# Run the agent
repo-repair --help
```

## Usage

### Service Management

```bash
# Check service status
systemctl status repo-repair.service

# Start/stop the service
sudo systemctl start repo-repair.service
sudo systemctl stop repo-repair.service

# View logs
journalctl -u repo-repair.service -f
```

### Manual Execution

```bash
# Fix permissions in a repository
repo-repair fix-permissions /path/to/repo

# Sync repository with remote
repo-repair sync-repos /path/to/repo --branch main

# Handle repository changes
repo-repair handle-changes /path/to/repo --change-type commit
```

### API Integration

The agent exposes REST API endpoints for integration:

```bash
# Health check
curl http://localhost:8081/health

# Execute capability
curl -X POST http://localhost:8081/execute \
  -H "Content-Type: application/json" \
  -d '{
    "capability": "fix_permissions",
    "parameters": {
      "target_path": "/path/to/repo",
      "fix_executable": true
    }
  }'
```

## Automated Triggers

### Git Hooks
The agent can be triggered by Git repository events:

```bash
# Install post-receive hook
cp templates/triggers/post-receive /path/to/repo/.git/hooks/
chmod +x /path/to/repo/.git/hooks/post-receive
```

### GitHub Actions
Integrate with GitHub Actions workflows:

```yaml
# .github/workflows/repo-repair.yml
name: Repository Repair
on: [push, pull_request]
jobs:
  repair:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Repository Repair
        run: |
          curl -sSL https://raw.githubusercontent.com/cbwinslow/oci-infrastructure/main/agents/repo_repair/scripts/deploy.sh | sudo bash
          repo-repair --repo-path=${{ github.workspace }} --auto-fix=true
```

### Webhooks
Configure webhook handlers for external triggers:

```bash
# Set up webhook handler
cp templates/triggers/webhook_handler.sh /usr/local/bin/
chmod +x /usr/local/bin/webhook_handler.sh

# Configure your webhook to POST to the handler
```

### Cron Jobs
Schedule regular repository maintenance:

```bash
# Install cron jobs
crontab templates/crontab.template

# Example cron entries:
# 0 2 * * * /opt/repo-repair/scripts/fix_permissions.sh --auto
# 0 * * * * /opt/repo-repair/scripts/sync_repos.sh --auto
```

## Monitoring and Logging

### Metrics Collection
The agent collects various metrics for monitoring:

- Execution time
- Success rate
- Files processed
- Errors encountered

### Health Checks
Regular health checks ensure the agent is functioning properly:

```bash
# Manual health check
curl http://localhost:8081/health

# Automated health monitoring
systemctl status repo-repair.service
```

### Log Management
Centralized logging with rotation:

```bash
# View application logs
tail -f /var/log/repo-repair/agent.log

# View system logs
journalctl -u repo-repair.service
```

## Security Considerations

### Sandbox Environment
The agent runs in a controlled sandbox with:
- Limited file system access
- Restricted command execution
- User privilege separation

### Permission Management
- Service runs under dedicated user account
- Minimal required permissions
- Secure configuration file handling

### Network Security
- Configurable endpoint access
- Token-based authentication
- SSL/TLS support for API communication

## Troubleshooting

### Common Issues

#### Registration Failure
```bash
# Check AI framework connectivity
curl -v http://localhost:8080/api/v1/health

# Verify authentication token
echo $AI_FRAMEWORK_TOKEN

# Check agent logs
journalctl -u repo-repair.service --since "1 hour ago"
```

#### Permission Errors
```bash
# Check service user permissions
sudo -u repo-repair ls -la /opt/repo-repair

# Verify file ownership
ls -la /opt/repo-repair/

# Fix permissions if needed
sudo chown -R repo-repair:repo-repair /opt/repo-repair
```

#### Service Start Failures
```bash
# Check service status
systemctl status repo-repair.service

# Verify configuration
sudo /opt/repo-repair/register_agent.sh --dry-run

# Check dependencies
which git jq curl
```

### Log Analysis
```bash
# Search for errors
journalctl -u repo-repair.service | grep ERROR

# Monitor real-time activity
journalctl -u repo-repair.service -f

# Check registration status
grep "registration" /var/log/repo-repair/agent.log
```

## Development and Customization

### Adding New Capabilities
1. Define capability in `config/capabilities.json`
2. Implement capability script in `scripts/`
3. Update agent configuration
4. Re-register with AI framework

### Custom Package Integration
1. Add package manager detection to `scripts/package_integration.sh`
2. Create package templates in `templates/`
3. Update deployment script

### Testing
```bash
# Run deployment in dry-run mode
./scripts/deploy.sh --dry-run

# Test individual capabilities
./scripts/fix_permissions.sh --help

# Validate configuration
jq . config/agent_config.json
```

## Integration Examples

### CI/CD Pipeline Integration
```yaml
# Example Jenkins pipeline
pipeline {
    agent any
    stages {
        stage('Repository Repair') {
            steps {
                sh 'repo-repair fix-permissions ${WORKSPACE}'
                sh 'repo-repair sync-repos ${WORKSPACE}'
            }
        }
    }
}
```

### Kubernetes Deployment
```yaml
# Example Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: repo-repair-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: repo-repair-agent
  template:
    spec:
      containers:
      - name: repo-repair
        image: repo-repair-agent:latest
        ports:
        - containerPort: 8081
        env:
        - name: AI_FRAMEWORK_ENDPOINT
          value: "http://ai-framework:8080/api/v1"
```

## Support and Contributing

For issues, feature requests, or contributions, please refer to the main project repository at https://github.com/cbwinslow/oci-infrastructure.

### License
This project is licensed under the MIT License - see the LICENSE file for details.

