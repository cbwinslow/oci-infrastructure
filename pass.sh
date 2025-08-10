#!/bin/bash

# CHANGE THIS to a strong password before running!
ADMIN_PASSWORD="YourStrongAdminPassword123!"

# Set the environment variable and re-run the demo configuration installer
sudo OPENSEARCH_INITIAL_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
    /usr/share/opensearch/plugins/opensearch-security/tools/install_demo_configuration.sh

# Optionally, finish any pending dpkg configuration (if the package install was interrupted)
sudo OPENSEARCH_INITIAL_ADMIN_PASSWORD="$ADMIN_PASSWORD" dpkg --configure opensearch
