output "cluster_name" {
  description = "Nombre del clúster EKS creado"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint para conectarse al clúster EKS"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR para las imágenes Docker"
  value       = aws_ecr_repository.review_service.repository_url
}