output "vault_instance_id" {
  description = "ID of the dedicated Vault EC2 instance"
  value       = aws_instance.vault.id
}

output "vault_private_ip" {
  description = "Private address for clients on the existing VPC"
  value       = aws_instance.vault.private_ip
}

output "vault_public_ip" {
  description = "Public address, only when assign_public_ip is enabled"
  value       = aws_instance.vault.public_ip
}

output "vault_security_group_id" {
  description = "Security group attached only to the Vault host"
  value       = aws_security_group.vault.id
}

output "vault_data_volume_id" {
  description = "Persistent encrypted EBS data volume; lifecycle prevents accidental Terraform destruction"
  value       = aws_ebs_volume.vault_data.id
}
