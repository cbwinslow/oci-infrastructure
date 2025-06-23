# Provider configuration
provider "oci" {
  region           = "us-ashburn-1"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

# Terraform configuration
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0.0"
}

# Data sources
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# VCN
resource "oci_core_vcn" "free_tier_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = "10.0.0.0/16"
  display_name   = "free-tier-vcn"
  dns_label      = "freetier"
}

# Internet Gateway
resource "oci_core_internet_gateway" "free_tier_ig" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.free_tier_vcn.id
  display_name   = "free-tier-ig"
}

# Route Table
resource "oci_core_route_table" "free_tier_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.free_tier_vcn.id
  display_name   = "free-tier-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.free_tier_ig.id
  }
}

# Public Subnet
resource "oci_core_subnet" "free_tier_subnet" {
  compartment_id    = var.compartment_id
  vcn_id           = oci_core_vcn.free_tier_vcn.id
  cidr_block       = "10.0.1.0/24"
  display_name     = "free-tier-subnet"
  dns_label        = "freetiersubnet"
  security_list_ids = [oci_core_security_list.free_tier_sl.id]
  route_table_id   = oci_core_route_table.free_tier_rt.id
}

# Security List
resource "oci_core_security_list" "free_tier_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.free_tier_vcn.id
  display_name   = "free-tier-security-list"

  # Allow inbound SSH
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow inbound HTTP
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # Allow inbound HTTPS
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Allow inbound ATP
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 1522
      max = 1522
    }
  }

  # Allow all outbound traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Compute Instance (Free Tier - AMD)
resource "oci_core_instance" "free_tier_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "free-tier-instance"
  shape              = "VM.Standard.E2.1.Micro"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 1
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.free_tier_subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = var.instance_image_id # Ubuntu 20.04 minimal
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# Autonomous Database (Free Tier)
resource "oci_database_autonomous_database" "free_tier_adb" {
  compartment_id           = var.compartment_id
  db_name                 = "FREETIERADB"
  display_name            = "free-tier-adb"
  db_workload             = "OLTP"
  is_free_tier            = true
  cpu_core_count          = 1
  data_storage_size_in_tbs = 1
  admin_password          = var.adb_password
  is_auto_scaling_enabled = false
  license_model           = "LICENSE_INCLUDED"
}

# Generate Wallet
resource "oci_database_autonomous_database_wallet" "free_tier_wallet" {
  autonomous_database_id = oci_database_autonomous_database.free_tier_adb.id
  password              = var.wallet_password
  generate_type         = "SINGLE"
  base64_encode_content = true
}

# Volume (Free Tier - 50GB)
resource "oci_core_volume" "free_tier_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "free-tier-volume"
  size_in_gbs        = 50
}

# Volume Attachment
resource "oci_core_volume_attachment" "free_tier_volume_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.free_tier_instance.id
  volume_id       = oci_core_volume.free_tier_volume.id
}

