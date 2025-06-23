# OCI Infrastructure Monitoring and Maintenance System

This comprehensive monitoring and maintenance system provides automated infrastructure management for Oracle Cloud Infrastructure (OCI) deployments.

## Overview

The system consists of the following components:

### Monitoring Infrastructure
- **Log Aggregation**: Centralized logging using OCI Logging service
- **Metrics Collection**: Real-time performance monitoring
- **Alerting Rules**: Automated notifications for critical events
- **Dashboards**: Grafana-based visualization

### Maintenance Procedures
- **Security Updates**: Automated security patches and hardening
- **Performance Optimization**: System tuning and resource optimization
- **Configuration Management**: Ansible-based infrastructure configuration
- **Backup Procedures**: Comprehensive data protection

## Directory Structure

```
monitoring/
├── monitoring.tf              # Terraform monitoring infrastructure
├── variables.tf              # Configuration variables
├── outputs.tf                # Infrastructure outputs
├── dashboards/               # Grafana dashboard configurations
│   └── oci-infrastructure-dashboard.json
└── README.md                 # This documentation

maintenance/
├── master_maintenance.sh     # Main orchestration script
├── security_updates.sh       # Security updates and hardening
├── performance_optimization.sh # Performance tuning
├── configuration_management.sh # Ansible configuration management
└── backup_procedures.sh      # Backup operations
```

## Quick Start

### 1. Deploy Monitoring Infrastructure

```bash
# Navigate to monitoring directory
cd monitoring/

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="compartment_id=YOUR_COMPARTMENT_OCID" \
                -var="alert_email=your-email@domain.com"

# Apply configuration
terraform apply
```

### 2. Setup Maintenance System

```bash
# Navigate to maintenance directory
cd ../maintenance/

# Setup maintenance environment
sudo ./master_maintenance.sh setup

# Run initial maintenance cycle
sudo ./master_maintenance.sh full
```

## Monitoring Components

### Log Groups and Sources

- **Application Logs**: Compute service logs
- **Infrastructure Logs**: VCN and networking logs  
- **Security Logs**: Identity and access logs (90-day retention)

### Alerting Rules

| Alert | Threshold | Severity | Notification |
|-------|-----------|----------|-------------|
| High CPU Usage | >80% | Critical | 2 hours |
| High Memory Usage | >85% | Warning | 4 hours |
| Low Disk Space | >90% | Critical | 1 hour |
| Network Connectivity | Lost connection | Critical | 30 minutes |

### Dashboards

The included Grafana dashboard provides:
- Real-time CPU, memory, and disk usage
- Network traffic visualization
- Active alerts table
- Log volume by type
- Health check status

## Maintenance Procedures

### Automated Maintenance Schedule

| Task | Frequency | Day/Time |
|------|-----------|----------|
| Security Updates | Weekly | Sunday 2:00 AM |
| Performance Optimization | Weekly | Monday 3:00 AM |
| Backup Procedures | Weekly | Sunday 1:00 AM |
| Configuration Management | Monthly | 1st of month 4:00 AM |
| Full Maintenance | Monthly | 1st of month 12:00 AM |

### Manual Maintenance Commands

```bash
# Run specific maintenance tasks
sudo ./master_maintenance.sh security      # Security updates only
sudo ./master_maintenance.sh performance   # Performance optimization
sudo ./master_maintenance.sh config        # Configuration management
sudo ./master_maintenance.sh backup        # Backup procedures

# Check maintenance status
./master_maintenance.sh status

# Install/update cron jobs
sudo ./master_maintenance.sh install-cron
```

## Security Features

### SSH Hardening
- Disable root login
- Disable password authentication
- Limit max authentication tries
- Enable X11 forwarding restrictions

### Firewall Configuration
- Enable fail2ban
- Configure firewalld rules
- Monitor failed login attempts

### System Auditing
- Enable auditd service
- Monitor file access
- Track security events

## Performance Optimization

### System Tuning
- Network buffer optimization
- Virtual memory tuning
- Disk I/O scheduler optimization
- TCP congestion control (BBR)

### Resource Cleanup
- Clear system caches
- Remove old packages
- Clean temporary files
- Vacuum journal logs

### Database Optimization
- PostgreSQL configuration tuning
- MySQL/MariaDB optimization
- Performance metrics collection

## Backup Strategy

### Backup Components
- **System Configurations**: /etc, /boot, SSH keys
- **Application Data**: /opt, /var/www, /srv, /usr/local
- **Databases**: PostgreSQL, MySQL/MariaDB dumps
- **User Data**: Home directories, user configurations
- **Logs**: System and application logs (7 days)

### Storage Locations
- **Local**: /backup directory
- **Cloud**: OCI Object Storage bucket
- **Retention**: 30 days (configurable)

### Recovery Procedures
Detailed recovery instructions are generated with each backup session and include:
- Step-by-step restoration procedures
- Database recovery commands
- Configuration restoration
- Verification steps

## Configuration Management

### Ansible Integration
- Automated configuration deployment
- Idempotent operations
- Role-based organization
- Inventory management

### Managed Components
- SSH configuration
- Firewall rules
- System monitoring
- Backup procedures
- Security policies

## Monitoring Setup

### Prerequisites
- OCI CLI configured
- Terraform installed
- Appropriate IAM permissions
- Email configuration (optional)

### Required Variables

| Variable | Description | Required |
|----------|-------------|----------|
| compartment_id | OCI Compartment OCID | Yes |
| tenancy_ocid | OCI Tenancy OCID | Yes |
| alert_email | Email for notifications | Yes |
| environment | Environment name | No (default: production) |
| health_check_targets | URLs to monitor | No |

### Terraform Outputs

After deployment, Terraform provides:
- Log group IDs
- Notification topic details
- Storage bucket information
- Alarm configurations
- Service connector details

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**
   ```bash
   # Check IAM policies
   oci iam policy list --compartment-id YOUR_COMPARTMENT_OCID
   ```

2. **Email Notifications Not Working**
   ```bash
   # Test email configuration
   echo "Test message" | mail -s "Test" your-email@domain.com
   ```

3. **Backup Failures**
   ```bash
   # Check disk space
   df -h /backup
   
   # Check OCI CLI configuration
   oci os ns get
   ```

4. **Performance Issues**
   ```bash
   # Check system resources
   ./master_maintenance.sh status
   
   # Review performance logs
   tail -f /var/log/oci-performance-optimization.log
   ```

### Log Locations

- Main maintenance log: `/var/log/oci-master-maintenance.log`
- Security maintenance: `/var/log/oci-security-maintenance.log`
- Performance optimization: `/var/log/oci-performance-optimization.log`
- Configuration management: `/var/log/oci-configuration-management.log`
- Backup procedures: `/var/log/oci-backup-procedures.log`

## Customization

### Modifying Alert Thresholds

Edit the monitoring variables in `variables.tf`:

```hcl
variable "alert_thresholds" {
  description = "Alert threshold configurations"
  type = object({
    cpu_threshold    = number
    memory_threshold = number
    disk_threshold   = number
  })
  default = {
    cpu_threshold    = 80
    memory_threshold = 85
    disk_threshold   = 90
  }
}
```

### Adding Custom Maintenance Tasks

1. Create a new script in the maintenance directory
2. Make it executable: `chmod +x new_script.sh`
3. Add it to the master maintenance script
4. Update cron jobs if needed

### Extending Monitoring

1. Add new alarm resources to `monitoring.tf`
2. Configure additional log sources
3. Update dashboard configurations
4. Modify notification settings

## Security Considerations

- All scripts require root privileges for full functionality
- Sensitive data is encrypted during backup
- Access logs are monitored and retained
- Regular security updates are applied automatically
- Configuration changes are logged and versioned

## Support and Maintenance

For issues or questions:
1. Check the troubleshooting section
2. Review log files for error messages
3. Verify system requirements and permissions
4. Test individual components separately

## License

This monitoring and maintenance system is provided as-is for use with OCI infrastructure management.

