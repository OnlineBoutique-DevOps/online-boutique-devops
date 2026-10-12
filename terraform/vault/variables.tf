variable "aws_region" {
  description = "AWS region containing the existing Online Boutique VPC"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Prefix for the dedicated Vault resources"
  type        = string
  default     = "online-boutique-vault"
}

variable "vpc_id" {
  description = "Existing Learner Lab VPC ID; supply after verifying it in the Lab"
  type        = string
}

variable "subnet_id" {
  description = "Existing subnet ID in vpc_id; verify its route and address capacity first"
  type        = string
}

variable "admin_cidr" {
  description = "Single approved administrator IPv4 CIDR for Vault HTTPS, e.g. the current Mac public IP /32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && can(regex("/32$", var.admin_cidr))
    error_message = "admin_cidr must be a valid single-host IPv4 CIDR ending in /32."
  }
}

variable "eks_cluster_security_group_id" {
  description = "Existing EKS cluster security group ID from the current Terraform output; no EKS SG is changed"
  type        = string
}

variable "instance_type" {
  description = "Small instance type suitable for a lab Vault server"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size_gib" {
  description = "Encrypted gp3 operating-system volume size in GiB"
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size_gib >= 8 && var.root_volume_size_gib <= 30
    error_message = "Use an 8-30 GiB root volume for this lab design."
  }
}

variable "vault_data_volume_size_gib" {
  description = "Separate encrypted gp3 volume for persistent Raft data"
  type        = number
  default     = 20

  validation {
    condition     = var.vault_data_volume_size_gib >= 10 && var.vault_data_volume_size_gib <= 50
    error_message = "Use a 10-50 GiB persistent Vault data volume for this lab design."
  }
}

variable "assign_public_ip" {
  description = "Set true only after confirming a public subnet, TLS, and the restricted admin CIDR; false requires private access such as SSM"
  type        = bool
  default     = false
}

variable "enable_ssh" {
  description = "Enable SSH only as an explicitly selected Ansible transport, restricted to admin_cidr"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Pre-existing EC2 key-pair name; required only when enable_ssh is true. Never commit the private key."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_ssh || (var.ssh_key_name != null && length(trimspace(var.ssh_key_name)) > 0)
    error_message = "Set ssh_key_name to an existing key pair when enable_ssh is true."
  }
}
