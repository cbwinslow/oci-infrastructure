variable "tenancy_ocid" {
  description = "The OCID of your tenancy"
  type        = string
}

variable "user_ocid" {
  description = "The OCID of the user calling the API"
  type        = string
}

variable "fingerprint" {
  description = "The fingerprint of the public key"
  type        = string
}

variable "private_key_path" {
  description = "The path to the private key file"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "compartment_id" {
  description = "The OCID of the compartment where resources will be created"
  type        = string
}

variable "instance_image_id" {
  description = "The OCID of the Ubuntu 20.04 image"
  type        = string
  # Find with: oci compute image list --compartment-id $COMPARTMENT_ID --operating-system "Canonical Ubuntu" --operating-system-version "20.04"
}

variable "ssh_public_key" {
  description = "The SSH public key to use for the instance"
  type        = string
}

variable "adb_password" {
  description = "The admin password for the Autonomous Database"
  type        = string
  sensitive   = true
}

variable "wallet_password" {
  description = "The password for the database wallet"
  type        = string
  sensitive   = true
}

