variable "aws_region" {
  description = "Región de AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Nombre del clúster EKS"
  type        = string
  default     = "online-boutique-cluster"
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes del clúster EKS"
  type        = string
  default     = "1.34"
}

variable "vpc_id" {
  description = "VPC donde vive el clúster (VPC por defecto del laboratorio)"
  type        = string
  default     = "vpc-071f079c1986866d2"
}

variable "subnet_ids" {
  description = "Subredes del clúster EKS (5 zonas de disponibilidad)"
  type        = list(string)
  default = [
    "subnet-0c7a08d9150abdeda",
    "subnet-0bbdd89e5c7d7e695",
    "subnet-03a12107c6a447e40",
    "subnet-0dfef9e3c56fbf7b2",
    "subnet-059ea6f018178e9a1",
  ]
}

variable "cluster_role_arn" {
  description = "Rol IAM del plano de control (creado por AWS Academy; voclabs no puede crear roles)"
  type        = string
  default     = "arn:aws:iam::532727285947:role/c225529a5691576l17073717t1w532727-LabEksClusterRole-TCHVxwSprtFo"
}

variable "node_role_arn" {
  description = "Rol IAM de los nodos EKS Auto Mode (creado por AWS Academy)"
  type        = string
  default     = "arn:aws:iam::532727285947:role/c225529a5691576l17073717t1w532727285-LabEksNodeRole-6imoPwuaYqi7"
}

variable "ecr_repository_prefix" {
  description = "Prefijo de los repositorios ECR"
  type        = string
  default     = "online-boutique"
}

variable "microservices" {
  description = "Microservicios con imagen propia en ECR (debe coincidir con la matriz de ci.yml)"
  type        = list(string)
  default = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "loadgenerator",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "reviewservice",
    "shippingservice",
    "shoppingassistantservice",
  ]
}
