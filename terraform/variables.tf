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
  default     = "vpc-02f7ad42245cb051c"
}

variable "subnet_ids" {
  description = "Subredes del clúster EKS (5 zonas de disponibilidad)"
  type        = list(string)
  default = [
    "subnet-028010d63aadf8e52",
    "subnet-0965d168b9e2cdfcc",
    "subnet-0f35a0c3989f0ad40",
    "subnet-0eaca19376331cc48",
    "subnet-001dd9c257e45f2cb",
  ]
}

variable "cluster_role_arn" {
  description = "Rol IAM del plano de control (creado por AWS Academy; voclabs no puede crear roles)"
  type        = string
  default     = "arn:aws:iam::392730678728:role/c233692a5878512l17581289t1w392730-LabEksClusterRole-5IDruBu7jfIq"
}

variable "node_role_arn" {
  description = "Rol IAM de los nodos EKS Auto Mode (creado por AWS Academy)"
  type        = string
  default     = "arn:aws:iam::392730678728:role/c233692a5878512l17581289t1w392730678-LabEksNodeRole-5YnAazZuQS7y"
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
