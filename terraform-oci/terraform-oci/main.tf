# Provider configuration
provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

# State backend configuration
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0.0"
}

# VCN for Database
resource "oci_core_vcn" "database_vcn" {
  compartment_id = var.compartment_id
  display_name   = "${var.db_name}-vcn"
  cidr_block     = var.vcn_cidr

  dns_label = "dbvcn"
}

# Internet Gateway
resource "oci_core_internet_gateway" "database_ig" {
  compartment_id = var.compartment_id
  display_name   = "${var.db_name}-ig"
  vcn_id         = oci_core_vcn.database_vcn.id
}

# Route Table
resource "oci_core_route_table" "database_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.database_vcn.id
  display_name   = "${var.db_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.database_ig.id
  }
}

# Security List
resource "oci_core_security_list" "database_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.database_vcn.id
  display_name   = "${var.db_name}-sl"

  # Allow SQL*Net inbound
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"  # Allow from any IP, adjust as needed

    tcp_options {
      min = 1521
      max = 1521
    }
  }

  # Allow HTTPS inbound for SQL Developer Web and APEX
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"  # Allow from any IP, adjust as needed

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Allow all outbound traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Subnet for Database
resource "oci_core_subnet" "database_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.database_vcn.id
  display_name   = "${var.db_name}-subnet"
  cidr_block     = var.subnet_cidr

  security_list_ids = [oci_core_security_list.database_sl.id]
  route_table_id    = oci_core_route_table.database_rt.id
  dns_label         = "dbsubnet"
}

# Autonomous Database (Free Tier)
resource "oci_database_autonomous_database" "database" {
  compartment_id           = var.compartment_id
  cpu_core_count          = 1  # Free tier: 1 OCPU
  data_storage_size_in_tbs = 1  # Free tier: 1 TB
  db_name                 = var.db_name
  admin_password          = var.db_admin_password
  display_name            = var.db_name
  db_version              = var.db_version
  db_workload             = var.db_workload
  is_free_tier            = true
  license_model           = "LICENSE_INCLUDED"

  # Free tier specific settings
  is_auto_scaling_enabled = false
  is_dedicated            = false

  # Backup configuration
  backup_retention_days = var.backup_retention_days
}

# Data source for Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# Generate Wallet
resource "oci_database_autonomous_database_wallet" "database_wallet" {
  autonomous_database_id = oci_database_autonomous_database.database.id
  password              = var.wallet_password
  generate_type         = "SINGLE"
  base64_encode_content = true
}

# Save wallet to a local file
resource "local_file" "database_wallet_file" {
  content_base64 = oci_database_autonomous_database_wallet.database_wallet.content
  filename       = "${path.module}/wallet/${var.db_name}_wallet.zip"

  depends_on = [oci_database_autonomous_database_wallet.database_wallet]
}

# Create database user
resource "oci_database_autonomous_database_database_user" "app_user" {
  autonomous_database_id = oci_database_autonomous_database.database.id
  username              = var.db_user_name
  password              = var.db_user_password
  roles                 = ["CONNECT", "RESOURCE"]
}

# Instance Subnet
resource "oci_core_subnet" "instance_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.database_vcn.id
  display_name   = "${var.db_name}-instance-subnet"
  cidr_block     = var.instance_subnet_cidr
  
  security_list_ids = [oci_core_security_list.instance_security_list.id]
  route_table_id    = oci_core_route_table.database_rt.id
  dns_label         = "instsubnet"
}

# Security List for Instance
resource "oci_core_security_list" "instance_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.database_vcn.id
  display_name   = "${var.db_name}-instance-security-list"

  # Allow SSH inbound
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow HTTPS inbound
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Allow HTTP inbound
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 80
      max = 80
    }
  }

  # Allow all outbound traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

# Compute Instance
resource "oci_core_instance" "app_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.db_name}-instance"
  shape               = var.instance_shape

  create_vnic_details {
    subnet_id        = oci_core_subnet.instance_subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = var.instance_image_id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  # Cloud-init script to install Oracle Instant Client and required packages
  extended_metadata = {
    user_data = base64encode(<<-EOF
      #!/bin/bash
      # Add Oracle repository
      sudo apt-get update
      sudo apt-get install -y alien
      sudo apt-get install -y libaio1
      
      # Download and install Oracle Instant Client
      wget https://download.oracle.com/otn_software/linux/instantclient/instantclient-basic-linuxx64.rpm
      sudo alien -i instantclient-basic-linuxx64.rpm
      
      # Set up environment variables
      echo 'export LD_LIBRARY_PATH=/usr/lib/oracle/client64/lib:$LD_LIBRARY_PATH' >> /home/ubuntu/.bashrc
      echo 'export ORACLE_HOME=/usr/lib/oracle/client64' >> /home/ubuntu/.bashrc
      
      # Create Oracle wallet directory
      mkdir -p /home/ubuntu/.oracle/wallet/${var.db_name}
      chown -R ubuntu:ubuntu /home/ubuntu/.oracle
    EOF
    )
  }
}

# Block Volume
resource "oci_core_volume" "app_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.db_name}-volume"
  size_in_gbs         = var.volume_size_in_gbs
}

# Volume Attachment
resource "oci_core_volume_attachment" "app_volume_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.app_instance.id
  volume_id       = oci_core_volume.app_volume.id
}

# NSG for Database Access
resource "oci_core_network_security_group" "database_security_group" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.database_vcn.id
  display_name   = "${var.db_name}-database-security-group"
}

# NSG Rules for Database Access
resource "oci_core_network_security_group_security_rule" "database_security_rule" {
  network_security_group_id = oci_core_network_security_group.database_security_group.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  
  source                    = oci_core_subnet.instance_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  
  tcp_options {
    destination_port_range {
      min = 1522
      max = 1522
    }
  }
}

