variable "region" {
  description = "The OCI region where resources will be created"
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "The region value must be a valid OCI region in the format: xx-region-n."
  }
}

variable "tenancy_ocid" {
  description = "OCID of your tenancy"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^ocid1\\.tenancy\\.oc1\\..+$", var.tenancy_ocid))
    error_message = "The tenancy_ocid value must be a valid OCI tenancy OCID."
  }
}

variable "user_ocid" {
  description = "OCID of the user who will be creating the resources"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^ocid1\\.user\\.oc1\\..+$", var.user_ocid))
    error_message = "The user_ocid value must be a valid OCI user OCID."
  }
}

variable "fingerprint" {
  description = "Fingerprint of the API private key"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[a-f0-9]{2}(:[a-f0-9]{2}){15}$", var.fingerprint))
    error_message = "The fingerprint must be a valid API key fingerprint in the format: xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx."
  }
}

variable "private_key_path" {
  description = "Path to the private key file"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
  validation {
    condition     = fileexists(pathexpand(var.private_key_path))
    error_message = "The private key file must exist at the specified path."
  }
}

# Database-specific variables
variable "compartment_id" {
  description = "OCID of the compartment where the database will be created"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.oc1\\..+$", var.compartment_id))
    error_message = "The compartment_id value must be a valid OCI compartment OCID."
  }
}

variable "db_name" {
  description = "The name of the database to create"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{1,11}$", var.db_name))
    error_message = "The database name must start with a letter, be 1-12 characters long, and contain only alphanumeric characters."
  }
}

variable "db_admin_password" {
  description = "Password for the database admin user"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[A-Za-z0-9_#$]+$", var.db_admin_password)) && length(var.db_admin_password) >= 12
    error_message = "The database password must be at least 12 characters long and contain only alphanumeric characters and _#$."
  }
}

variable "db_version" {
  description = "The version of the database software"
  type        = string
  default     = "19c"
  validation {
    condition     = contains(["19c", "21c"], var.db_version)
    error_message = "Supported database versions are: 19c, 21c."
  }
}

variable "db_workload" {
  description = "The database workload type"
  type        = string
  default     = "OLTP"
  validation {
    condition     = contains(["OLTP", "DW", "AJD", "APEX"], var.db_workload)
    error_message = "Supported workload types for Autonomous Database are: OLTP, DW (Data Warehouse), AJD (JSON Database), APEX."
  }
}

variable "vcn_cidr" {
  description = "CIDR block for the Virtual Cloud Network"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "The VCN CIDR must be a valid CIDR block."
  }
}

variable "subnet_cidr" {
  description = "CIDR block for the database subnet"
  type        = string
  default     = "10.0.1.0/24"
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "The subnet CIDR must be a valid CIDR block."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain automatic backups"
  type        = number
  default     = 30
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 60
    error_message = "Backup retention days must be between 7 and 60."
  }
}

variable "wallet_password" {
  description = "Password to protect the wallet zip file"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.wallet_password) >= 8
    error_message = "Wallet password must be at least 8 characters long."
  }
}

# Compute Instance Variables
variable "instance_shape" {
  description = "The shape of compute instance to launch"
  type        = string
  default     = "VM.Standard.E2.1.Micro" # Free tier eligible
}

variable "instance_image_id" {
  description = "The OCID of the Ubuntu image to use"
  type        = string
  # You'll need to provide the OCID of an Ubuntu image in your region
}

variable "ssh_public_key" {
  description = "The SSH public key to use for the instance"
  type        = string
}

# Network Variables
variable "instance_subnet_cidr" {
  description = "CIDR block for the instance subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# Volume Variables
variable "volume_size_in_gbs" {
  description = "Size of the block volume in GBs"
  type        = number
  default     = 50
}

# Database User Variables
variable "db_user_name" {
  description = "Username for the database user to create"
  type        = string
  default     = "app_user"
}

variable "db_user_password" {
  description = "Password for the database user"
  type        = string
  sensitive   = true
}

# Security Variables
variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access - restrict to specific IPs for better security"
  type        = string
  default     = "0.0.0.0/0" # Default allows all - CHANGE THIS for production!
  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "The allowed SSH CIDR must be a valid CIDR block."
  }
}

