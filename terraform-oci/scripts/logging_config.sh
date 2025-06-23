#!/bin/bash

# =============================================================================
# Logging Configuration
# =============================================================================
# This file contains configuration settings for the logging and reporting
# system. Source this file to set up the logging environment.
# =============================================================================

# Set log directory to a location the user has permissions for
export LOG_DIR="${LOG_DIR:-${HOME}/CBW_SHARED_STORAGE/oci-infrastructure/logs}"
export LOG_FILE="${LOG_FILE:-${LOG_DIR}/infrastructure.log}"
export STATUS_FILE="${STATUS_FILE:-${LOG_DIR}/status.json}"
export REPORT_FILE="${REPORT_FILE:-${LOG_DIR}/status_report.txt}"

# Enable debug logging if needed
export DEBUG="${DEBUG:-false}"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

echo "Logging configuration loaded:"
echo "  LOG_DIR: $LOG_DIR"
echo "  LOG_FILE: $LOG_FILE"
echo "  STATUS_FILE: $STATUS_FILE"
echo "  REPORT_FILE: $REPORT_FILE"
echo "  DEBUG: $DEBUG"

