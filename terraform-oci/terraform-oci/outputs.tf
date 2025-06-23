output "region" {
  description = "The region where the resources are created"
  value       = var.region
}

output "tenancy_ocid" {
  description = "The tenancy OCID used for authentication"
  value       = var.tenancy_ocid
  sensitive   = true
}

output "user_ocid" {
  description = "The user OCID used for authentication"
  value       = var.user_ocid
  sensitive   = true
}

# Database outputs
output "autonomous_database_id" {
  description = "OCID of the created Autonomous Database"
  value       = oci_database_autonomous_database.database.id
}

output "autonomous_database_state" {
  description = "The current state of the Autonomous Database"
  value       = oci_database_autonomous_database.database.state
}

output "autonomous_database_connection_strings" {
  description = "Connection strings for the Autonomous Database"
  value       = oci_database_autonomous_database.database.connection_strings
  sensitive   = true
}

output "autonomous_database_connection_urls" {
  description = "Connection URLs for the Autonomous Database - Available in OCI Console"
  value = {
    note = "Connection URLs are available in the OCI Console under Autonomous Database > DB Connection"
    console_url = "https://cloud.oracle.com/db/autonomous/"
  }
  sensitive = false
}

output "autonomous_database_wallet" {
  description = "Information about the Autonomous Database wallet"
  value = {
    wallet_type = "INSTANCE"
  }
}

output "autonomous_database_backup_config" {
  description = "The backup configuration"
  value = {
    backup_policy = "Automatic backups are enabled by default for Autonomous Database"
    retention_policy = "Automatic retention according to Oracle's backup policy"
  }
}

# Instance Outputs
output "instance_public_ip" {
  description = "The public IP address of the instance"
  value       = oci_core_instance.app_instance.public_ip
}

output "instance_private_ip" {
  description = "The private IP address of the instance"
  value       = oci_core_instance.app_instance.private_ip
}

# Database Connection Information
output "database_connection_info" {
  description = "Database connection information"
  value = {
    username        = var.db_user_name
    service_name    = "${var.db_name}_high"
    connection_url  = "${var.db_name}_high?wallet_location=/home/ubuntu/.oracle/wallet/${var.db_name}"
    wallet_location = "/home/ubuntu/.oracle/wallet/${var.db_name}"
    tns_admin       = "/home/ubuntu/.oracle/wallet/${var.db_name}"
  }
  sensitive = true
}

# Volume Information
output "volume_info" {
  description = "Block volume information"
  value = {
    id          = oci_core_volume.app_volume.id
    size_in_gbs = oci_core_volume.app_volume.size_in_gbs
    state       = oci_core_volume.app_volume.state
  }
}

# Security Group Information
output "security_groups" {
  description = "Security group information"
  value = {
    instance_security_list  = oci_core_security_list.instance_security_list.id
    database_security_group = oci_core_network_security_group.database_security_group.id
  }
}

# Connection String Examples
output "connection_examples" {
  description = "Example connection strings for different languages"
  value = {
    python = <<-EOT
      import cx_Oracle
      
      connection = cx_Oracle.connect(
          user="${var.db_user_name}",
          password="your_password_here",
          dsn="${var.db_name}_high",
          config_dir="/home/ubuntu/.oracle/wallet/${var.db_name}"
      )
    EOT

    typescript = <<-EOT
      import oracledb from 'oracledb';
      
      const connection = await oracledb.getConnection({
        user: "${var.db_user_name}",
        password: "your_password_here",
        connectString: "${var.db_name}_high",
        configDir: "/home/ubuntu/.oracle/wallet/${var.db_name}"
      });
    EOT

    jdbc = "jdbc:oracle:thin:@${var.db_name}_high?TNS_ADMIN=/home/ubuntu/.oracle/wallet/${var.db_name}"

    sqlplus = "sqlplus ${var.db_user_name}@${var.db_name}_high"
  }
  sensitive = true
}

# Monitoring and Logging Outputs
output "log_group_info" {
  description = "Log group information"
  value = {
    id           = oci_logging_log_group.example.id
    display_name = oci_logging_log_group.example.display_name
    state        = oci_logging_log_group.example.state
  }
}

output "log_info" {
  description = "Log information"
  value = {
    id           = oci_logging_log.example.id
    display_name = oci_logging_log.example.display_name
    log_type     = oci_logging_log.example.log_type
    state        = oci_logging_log.example.state
  }
}

output "monitoring_config" {
  description = "Instance monitoring configuration status"
  value = {
    monitoring_enabled = true
    management_enabled = true
    plugins_enabled    = true
  }
}

