variable "aws_region" {
  description = "Región de AWS donde se creará el clúster"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Nombre del clúster EKS"
  type        = string
  default     = "online-boutique-cluster"
}