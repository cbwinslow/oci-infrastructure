# TFLint Configuration File
# This file configures TFLint for Terraform code quality and style checking

config {
  # Enable module inspection
  module = true
  
  # Force exit with non-zero code on warnings
  force = false
  
  # Disable colored output
  disabled_by_default = false
}

# Core TFLint rules
rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  
  variable {
    format = "snake_case"
  }
  
  locals {
    format = "snake_case"
  }
  
  output {
    format = "snake_case"
  }
  
  resource {
    format = "snake_case"
  }
  
  module {
    format = "snake_case"
  }
  
  data {
    format = "snake_case"
  }
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}

# OCI-specific plugin
plugin "terraform-linters/tflint-ruleset-terraform" {
  enabled = true
  version = "0.5.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

# AWS plugin (for general cloud best practices, if applicable)
plugin "terraform-linters/tflint-ruleset-aws" {
  enabled = false
  version = "0.21.2"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Custom rules for OCI
rule "oci_compute_instance_naming" {
  enabled = true
}

rule "oci_security_group_ingress_anywhere" {
  enabled = true
}

rule "oci_security_group_egress_anywhere" {
  enabled = true
}

# Ignore certain files/directories
rule "terraform_module_version" {
  enabled = false  # Disable if using local modules
}

# Variable validation rules
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

