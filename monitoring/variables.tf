# Variables for OCI Monitoring Infrastructure

variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "tenancy_ocid" {
  description = "The OCID of the tenancy"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "alert_email" {
  description = "Email address for receiving alerts"
  type        = string
}

variable "health_check_targets" {
  description = "List of URLs/IPs to monitor for health checks"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "security_log_retention_days" {
  description = "Number of days to retain security logs"
  type        = number
  default     = 90
}

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

variable "notification_settings" {
  description = "Notification settings for different alert types"
  type = object({
    critical_repeat_duration = string
    warning_repeat_duration  = string
    info_repeat_duration     = string
  })
  default = {
    critical_repeat_duration = "PT1H"
    warning_repeat_duration  = "PT4H"
    info_repeat_duration     = "PT24H"
  }
}

