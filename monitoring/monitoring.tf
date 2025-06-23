# OCI Monitoring Infrastructure
# This file defines monitoring, logging, and alerting components

terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

# Log Group for centralized logging
resource "oci_logging_log_group" "main_log_group" {
  compartment_id = var.compartment_id
  display_name   = "main-log-group"
  description    = "Central log group for all application and infrastructure logs"

  freeform_tags = {
    Environment = var.environment
    Project     = "oci-infrastructure"
    Component   = "logging"
  }
}

# Application Logs
resource "oci_logging_log" "application_logs" {
  display_name       = "application-logs"
  log_group_id       = oci_logging_log_group.main_log_group.id
  log_type          = "SERVICE"
  is_enabled        = true
  retention_duration = 30

  configuration {
    source {
      category    = "all"
      resource    = var.compartment_id
      service     = "compute"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  freeform_tags = {
    Environment = var.environment
    LogType     = "application"
  }
}

# Infrastructure Logs
resource "oci_logging_log" "infrastructure_logs" {
  display_name       = "infrastructure-logs"
  log_group_id       = oci_logging_log_group.main_log_group.id
  log_type          = "SERVICE"
  is_enabled        = true
  retention_duration = 30

  configuration {
    source {
      category    = "all"
      resource    = var.compartment_id
      service     = "vcn"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  freeform_tags = {
    Environment = var.environment
    LogType     = "infrastructure"
  }
}

# Security Logs
resource "oci_logging_log" "security_logs" {
  display_name       = "security-logs"
  log_group_id       = oci_logging_log_group.main_log_group.id
  log_type          = "SERVICE"
  is_enabled        = true
  retention_duration = 90

  configuration {
    source {
      category    = "all"
      resource    = var.compartment_id
      service     = "identity"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  freeform_tags = {
    Environment = var.environment
    LogType     = "security"
  }
}

# Custom Metric for CPU Usage
resource "oci_monitoring_alarm" "high_cpu_alarm" {
  compartment_id        = var.compartment_id
  display_name         = "High CPU Usage Alert"
  is_enabled           = true
  metric_compartment_id = var.compartment_id
  namespace            = "oci_computeagent"
  query                = "CpuUtilization[1m].mean() > 80"
  severity             = "CRITICAL"
  
  destinations = [oci_ons_notification_topic.alerts_topic.id]
  
  body = "CPU usage has exceeded 80% on one or more instances."
  
  repeat_notification_duration = "PT2H"
  
  freeform_tags = {
    Environment = var.environment
    AlertType   = "performance"
  }
}

# Memory Usage Alarm
resource "oci_monitoring_alarm" "high_memory_alarm" {
  compartment_id        = var.compartment_id
  display_name         = "High Memory Usage Alert"
  is_enabled           = true
  metric_compartment_id = var.compartment_id
  namespace            = "oci_computeagent"
  query                = "MemoryUtilization[1m].mean() > 85"
  severity             = "WARNING"
  
  destinations = [oci_ons_notification_topic.alerts_topic.id]
  
  body = "Memory usage has exceeded 85% on one or more instances."
  
  repeat_notification_duration = "PT4H"
  
  freeform_tags = {
    Environment = var.environment
    AlertType   = "performance"
  }
}

# Disk Space Alarm
resource "oci_monitoring_alarm" "low_disk_space_alarm" {
  compartment_id        = var.compartment_id
  display_name         = "Low Disk Space Alert"
  is_enabled           = true
  metric_compartment_id = var.compartment_id
  namespace            = "oci_computeagent"
  query                = "DiskUtilization[1m].mean() > 90"
  severity             = "CRITICAL"
  
  destinations = [oci_ons_notification_topic.alerts_topic.id]
  
  body = "Disk usage has exceeded 90% on one or more instances."
  
  repeat_notification_duration = "PT1H"
  
  freeform_tags = {
    Environment = var.environment
    AlertType   = "storage"
  }
}

# Network Connectivity Alarm
resource "oci_monitoring_alarm" "network_connectivity_alarm" {
  compartment_id        = var.compartment_id
  display_name         = "Network Connectivity Issues"
  is_enabled           = true
  metric_compartment_id = var.compartment_id
  namespace            = "oci_vcn"
  query                = "VnicConnections[1m].mean() < 1"
  severity             = "CRITICAL"
  
  destinations = [oci_ons_notification_topic.alerts_topic.id]
  
  body = "Network connectivity issues detected. Instance may be unreachable."
  
  repeat_notification_duration = "PT30M"
  
  freeform_tags = {
    Environment = var.environment
    AlertType   = "network"
  }
}

# Notification Topic for Alerts
resource "oci_ons_notification_topic" "alerts_topic" {
  compartment_id = var.compartment_id
  name          = "infrastructure-alerts"
  description   = "Topic for infrastructure monitoring alerts"

  freeform_tags = {
    Environment = var.environment
    Component   = "alerting"
  }
}

# Email Subscription for Alerts
resource "oci_ons_subscription" "email_alerts" {
  compartment_id = var.compartment_id
  endpoint      = var.alert_email
  protocol      = "EMAIL"
  topic_id      = oci_ons_notification_topic.alerts_topic.id

  freeform_tags = {
    Environment = var.environment
    NotificationType = "email"
  }
}

# Service Connector Hub for log aggregation
resource "oci_sch_service_connector" "log_aggregator" {
  compartment_id = var.compartment_id
  display_name   = "log-aggregator-connector"
  description    = "Aggregates logs from multiple sources"

  source {
    kind = "logging"
    log_sources {
      compartment_id = var.compartment_id
      log_group_id   = oci_logging_log_group.main_log_group.id
    }
  }

  target {
    kind = "objectstorage"
    compartment_id = var.compartment_id
    bucket_name    = oci_objectstorage_bucket.logs_bucket.name
    namespace      = data.oci_objectstorage_namespace.tenant_namespace.namespace

    object_name_prefix = "logs/"
  }

  freeform_tags = {
    Environment = var.environment
    Component   = "log-aggregation"
  }
}

# Object Storage bucket for log archival
resource "oci_objectstorage_bucket" "logs_bucket" {
  compartment_id = var.compartment_id
  name          = "infrastructure-logs-${var.environment}"
  namespace     = data.oci_objectstorage_namespace.tenant_namespace.namespace

  versioning = "Enabled"

  lifecycle_policy_rules {
    name    = "archive-old-logs"
    enabled = true
    
    object_name_filter {
      inclusion_patterns = ["logs/*"]
    }
    
    actions {
      type = "ARCHIVE"
      time_amount = 90
      time_unit   = "DAYS"
    }
  }

  freeform_tags = {
    Environment = var.environment
    Component   = "log-storage"
  }
}

# Data source for tenant namespace
data "oci_objectstorage_namespace" "tenant_namespace" {
  compartment_id = var.tenancy_ocid
}

# Health Check for critical services
resource "oci_health_checks_http_monitor" "service_health_check" {
  compartment_id      = var.compartment_id
  display_name        = "critical-service-health"
  interval_in_seconds = 30
  is_enabled         = true
  protocol           = "HTTPS"
  targets            = var.health_check_targets

  freeform_tags = {
    Environment = var.environment
    Component   = "health-monitoring"
  }
}

