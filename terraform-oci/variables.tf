variable "compartment_id" {
  description = "The OCID of the compartment where resources will be created"
  type        = string
}

variable "availability_domain" {
  description = "The availability domain where resources will be created"
  type        = string
}

variable "image_id" {
  description = "The OCID of the image to be used for the instance"
  type        = string
}

variable "subnet_id" {
  description = "The OCID of the subnet where the instance will be created"
  type        = string
}

variable "tenancy_ocid" {
  description = "The OCID of your tenancy"
  type        = string
}

variable "user_ocid" {
  description = "The OCID of the user"
  type        = string
}

variable "fingerprint" {
  description = "The fingerprint of the API key"
  type        = string
}

variable "private_key_path" {
  description = "The path to the private key file"
  type        = string
}

variable "region" {
  description = "The region where resources will be created"
  type        = string
}

