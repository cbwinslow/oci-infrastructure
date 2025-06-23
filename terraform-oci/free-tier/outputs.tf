output "instance_public_ip" {
  description = "The public IP address of the instance"
  value       = oci_core_instance.free_tier_instance.public_ip
}

output "autonomous_database_id" {
  description = "The OCID of the Autonomous Database"
  value       = oci_database_autonomous_database.free_tier_adb.id
}

output "connection_strings" {
  description = "The connection strings for the Autonomous Database"
  value       = oci_database_autonomous_database.free_tier_adb.connection_strings
  sensitive   = true
}

output "database_url" {
  description = "The URL to access the database"
  value       = oci_database_autonomous_database.free_tier_adb.url
}

output "wallet_content" {
  description = "The base64-encoded wallet content"
  value       = oci_database_autonomous_database_wallet.free_tier_wallet.content
  sensitive   = true
}

