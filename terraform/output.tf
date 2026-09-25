# Outputs de Terraform

output "cluster_name" {
  description = "Nombre del clúster EKS"
  value       = aws_eks_cluster.online_boutique.name
}

output "cluster_endpoint" {
  description = "Endpoint del API server de Kubernetes"
  value       = aws_eks_cluster.online_boutique.endpoint
}

output "cluster_version" {
  description = "Versión de Kubernetes del clúster"
  value       = aws_eks_cluster.online_boutique.version
}

output "cluster_security_group_id" {
  description = "Security group del clúster (donde se abre el NodePort del frontend)"
  value       = aws_eks_cluster.online_boutique.vpc_config[0].cluster_security_group_id
}

output "kubeconfig_command" {
  description = "Comando para configurar kubectl contra el clúster"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.online_boutique.name} --region ${var.aws_region}"
}

output "ecr_registry" {
  description = "Registro ECR de la cuenta"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "URLs de todos los repositorios ECR de los microservicios"
  value       = { for name, repo in aws_ecr_repository.microservice : name => repo.repository_url }
}

data "aws_caller_identity" "current" {}
