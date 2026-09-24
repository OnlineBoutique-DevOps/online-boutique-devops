# Outputs de Terraform
# NOTA: Los outputs de EKS están comentados temporalmente debido a problemas de IAM en AWS Academy
# Descomentar cuando se resuelvan los permisos IAM para EKS

# output "cluster_name" {
#   description = "Nombre del clúster EKS creado"
#   value       = module.eks.cluster_name
# }

# output "cluster_endpoint" {
#   description = "Endpoint para conectarse al clúster EKS"
#   value       = module.eks.cluster_endpoint
# }

output "ecr_repository_url" {
  description = "URL del repositorio ECR para las imágenes Docker"
  value       = aws_ecr_repository.review_service.repository_url
}

output "ecr_repository_urls" {
  description = "URLs de todos los repositorios ECR para los microservicios"
  value = {
    adservice            = aws_ecr_repository.ad_service.repository_url
    cartservice          = aws_ecr_repository.cart_service.repository_url
    checkoutservice      = aws_ecr_repository.checkout_service.repository_url
    currencyservice      = aws_ecr_repository.currency_service.repository_url
    emailservice         = aws_ecr_repository.email_service.repository_url
    frontend             = aws_ecr_repository.frontend.repository_url
    loadgenerator        = aws_ecr_repository.load_generator.repository_url
    paymentservice       = aws_ecr_repository.payment_service.repository_url
    productcatalogservice = aws_ecr_repository.product_catalog_service.repository_url
    recommendationservice = aws_ecr_repository.recommendation_service.repository_url
    reviewservice        = aws_ecr_repository.review_service.repository_url
    shippingservice      = aws_ecr_repository.shipping_service.repository_url
  }
}