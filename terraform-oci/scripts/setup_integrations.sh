#!/bin/bash

# Script to set up additional integrations for CloudCurio Oracle

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INTEGRATIONS_DIR="${PROJECT_ROOT}/integrations"

# Create directories
mkdir -p "$INTEGRATIONS_DIR"
mkdir -p "${INTEGRATIONS_DIR}/terraform"
mkdir -p "${INTEGRATIONS_DIR}/docker"
mkdir -p "${INTEGRATIONS_DIR}/kubernetes"

# Terraform Cloud integration
setup_terraform_cloud() {
    cat > "${INTEGRATIONS_DIR}/terraform/cloud.tf" << EOF
terraform {
  cloud {
    organization = "cloudcurio"
    workspaces {
      name = "cloudcurio-oracle"
    }
  }
}
EOF
}

# Datadog integration
setup_datadog() {
    cat > "${INTEGRATIONS_DIR}/terraform/datadog.tf" << EOF
resource "datadog_monitor" "oci_cost" {
  name               = "OCI Cost Alert"
  type               = "metric alert"
  message           = "OCI costs have exceeded threshold"
  
  query = "avg(last_1h):avg:oci.billing.total{*} > \${var.cost_threshold}"
  
  monitor_thresholds {
    critical = var.cost_threshold
    warning  = var.cost_threshold * 0.8
  }
}

resource "datadog_dashboard" "oci" {
  title       = "OCI Overview"
  description = "Overview of OCI resources and costs"
  layout_type = "ordered"
  
  widget {
    alert_graph_definition {
      alert_id = datadog_monitor.oci_cost.id
      viz_type = "timeseries"
      title    = "OCI Cost Trend"
    }
  }
}
EOF
}

# Slack integration
setup_slack() {
    cat > "${PROJECT_ROOT}/.github/workflows/slack-notify.yml" << EOF
name: Slack Notification

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  issues:
    types: [opened, closed, reopened]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Slack Notification
      uses: rtCamp/action-slack-notify@v2
      env:
        SLACK_WEBHOOK: \${{ secrets.SLACK_WEBHOOK }}
        SLACK_CHANNEL: cloudcurio-alerts
        SLACK_COLOR: \${{ job.status }}
        SLACK_TITLE: CloudCurio Oracle Update
EOF
}

# PagerDuty integration
setup_pagerduty() {
    cat > "${INTEGRATIONS_DIR}/terraform/pagerduty.tf" << EOF
resource "pagerduty_service" "cloudcurio" {
  name = "CloudCurio Oracle"
  description = "Manages OCI infrastructure alerts"
  auto_resolve_timeout = 14400
  acknowledgement_timeout = 600
  escalation_policy = var.pagerduty_policy_id
}

resource "pagerduty_service_integration" "cloudwatch" {
  name = "CloudWatch"
  service = pagerduty_service.cloudcurio.id
  vendor = "PagerDuty Cloudwatch Integration"
}
EOF
}

# Prometheus and Grafana integration
setup_monitoring() {
    cat > "${INTEGRATIONS_DIR}/kubernetes/monitoring.yaml" << EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cloudcurio-oracle
spec:
  selector:
    matchLabels:
      app: cloudcurio-oracle
  endpoints:
  - port: metrics

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: metrics.cloudcurio.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
EOF
}

# New Relic integration
setup_newrelic() {
    cat > "${INTEGRATIONS_DIR}/terraform/newrelic.tf" << EOF
resource "newrelic_alert_policy" "cloudcurio" {
  name = "CloudCurio Oracle"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "oci_error" {
  policy_id = newrelic_alert_policy.cloudcurio.id
  name = "High Error Rate"
  type = "static"
  
  nrql {
    query = "SELECT percentage(count(*), WHERE error IS TRUE) FROM Transaction WHERE appName = 'CloudCurio'"
  }
  
  critical {
    operator = "above"
    threshold = 5
    threshold_duration = 300
  }
}
EOF
}

# HashiCorp Vault integration
setup_vault() {
    cat > "${INTEGRATIONS_DIR}/terraform/vault.tf" << EOF
resource "vault_mount" "oci" {
  path = "oci"
  type = "kv"
  options = {
    version = "2"
  }
}

resource "vault_generic_secret" "oci_credentials" {
  path = "oci/credentials"
  
  data_json = jsonencode({
    tenancy_ocid = var.tenancy_ocid
    user_ocid = var.user_ocid
    fingerprint = var.fingerprint
  })
}
EOF
}

# SonarQube integration
setup_sonarqube() {
    cat > "${PROJECT_ROOT}/.github/workflows/sonarqube.yml" << EOF
name: SonarQube Analysis

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  sonarqube:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: SonarQube Scan
      uses: sonarsource/sonarqube-scan-action@master
      env:
        SONAR_TOKEN: \${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: \${{ secrets.SONAR_HOST_URL }}
EOF
}

# Snyk integration
setup_snyk() {
    cat > "${PROJECT_ROOT}/.github/workflows/snyk.yml" << EOF
name: Snyk Security Scan

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
    
    - name: Run Snyk to check for vulnerabilities
      uses: snyk/actions/iac@master
      env:
        SNYK_TOKEN: \${{ secrets.SNYK_TOKEN }}
      with:
        args: --severity-threshold=high
EOF
}

# Function to run all integration setups
setup_all_integrations() {
    echo "Setting up all integrations..."
    
    setup_terraform_cloud
    setup_datadog
    setup_slack
    setup_pagerduty
    setup_monitoring
    setup_newrelic
    setup_vault
    setup_sonarqube
    setup_snyk
    
    echo "All integrations configured successfully!"
}

# Run setup if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_all_integrations
fi

