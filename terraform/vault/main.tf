terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnet" "vault" {
  id = var.subnet_id
}

resource "aws_ebs_volume" "vault_data" {
  availability_zone = data.aws_subnet.vault.availability_zone
  type              = "gp3"
  size              = var.vault_data_volume_size_gib
  encrypted         = true

  tags = {
    Name      = "${var.name}-data"
    ManagedBy = "Terraform"
    Purpose   = "Persistent Vault Raft data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "vault" {
  name        = "${var.name}-sg"
  description = "Restricted HTTPS access to the dedicated Vault host"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    description = "Vault HTTPS/API only from the approved administrator CIDR"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description     = "Vault HTTPS/API from the existing EKS cluster security group"
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      description = "Optional Ansible SSH access from the approved administrator CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.admin_cidr]
    }
  }

  egress {
    description = "HTTPS for operating system and Vault package retrieval"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS to the existing VPC resolver network"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.existing.cidr_block]
  }

  egress {
    description = "DNS over TCP to the existing VPC resolver network"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing.cidr_block]
  }

  tags = {
    Name      = "${var.name}-sg"
    ManagedBy = "Terraform"
    Purpose   = "Vault phase 3"
  }
}

resource "aws_instance" "vault" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.vault.id
  vpc_security_group_ids      = [aws_security_group.vault.id]
  key_name                    = var.enable_ssh ? var.ssh_key_name : null
  associate_public_ip_address = var.assign_public_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gib
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  lifecycle {
    precondition {
      condition     = data.aws_subnet.vault.vpc_id == data.aws_vpc.existing.id
      error_message = "subnet_id must belong to the existing vpc_id."
    }
  }

  tags = {
    Name      = var.name
    ManagedBy = "Terraform"
    Purpose   = "Dedicated Vault host outside EKS"
  }
}

resource "aws_volume_attachment" "vault_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.vault_data.id
  instance_id = aws_instance.vault.id
}
