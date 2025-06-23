# Outputs for OCI Monitoring Infrastructure

output "log_group_id" {
  description = "OCID of the main log group"
  value       = oci_logging_log_group.main_log_group.id
}

output "log_group_name" {
  description = "Name of the main log group"
  value       = oci_logging_log_group.main_log_group.display_name
}

output "application_log_id" {
  description = "OCID of the application log"
  value       = oci_logging_log.application_logs.id
}

output "infrastructure_log_id" {
  description = "OCID of the infrastructure log"
  value       = oci_logging_log.infrastructure_logs.id
}

output "security_log_id" {
  description = "OCID of the security log"
  value       = oci_logging_log.security_logs.id
}

output "notification_topic_id" {
  description = "OCID of the notification topic for alerts"
  value       = oci_ons_notification_topic.alerts_topic.id
}

output "notification_topic_name" {
  description = "Name of the notification topic"
  value       = oci_ons_notification_topic.alerts_topic.name
}

output "logs_bucket_name" {
  description = "Name of the logs storage bucket"
  value       = oci_objectstorage_bucket.logs_bucket.name
}

output "logs_bucket_namespace" {
  description = "Namespace of the logs storage bucket"
  value       = oci_objectstorage_bucket.logs_bucket.namespace
}

output "service_connector_id" {
  description = "OCID of the service connector for log aggregation"
  value       = oci_sch_service_connector.log_aggregator.id
}

output "alarm_ids" {
  description = "Map of alarm names to their OCIDs"
  value = {
    high_cpu              = oci_monitoring_alarm.high_cpu_alarm.id
    high_memory          = oci_monitoring_alarm.high_memory_alarm.id
    low_disk_space       = oci_monitoring_alarm.low_disk_space_alarm.id
    network_connectivity = oci_monitoring_alarm.network_connectivity_alarm.id
  }
}

output "health_check_id" {
  description = "OCID of the health check monitor"
  value       = oci_health_checks_http_monitor.service_health_check.id
}

output "monitoring_summary" {
  description = "Summary of monitoring components deployed"
  value = {
    log_group_id         = oci_logging_log_group.main_log_group.id
    notification_topic   = oci_ons_notification_topic.alerts_topic.name
    logs_bucket         = oci_objectstorage_bucket.logs_bucket.name
    total_alarms        = 4
    log_retention_days  = 30
    security_retention  = 90
  }
}

