# Infraestructura de Online Boutique en AWS (cuenta 532727285947, us-east-1)
#
# NOTA SOBRE AWS ACADEMY: el rol de laboratorio (voclabs) no permite crear
# roles IAM ni proveedores OIDC. Por eso los roles del clúster y de los nodos
# se referencian como variables (fueron creados por el laboratorio) en lugar
# de declararse aquí. La VPC utilizada es la VPC por defecto de la cuenta.

# 1. Red: VPC por defecto del laboratorio y sus subredes
data "aws_vpc" "lab" {
  id = var.vpc_id
}

data "aws_subnets" "lab" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab.id]
  }
  filter {
    name   = "subnet-id"
    values = var.subnet_ids
  }
}

# 2. Clúster de Kubernetes (Amazon EKS en modo Auto)
# EKS Auto Mode delega a AWS la creación y ciclo de vida de las instancias EC2
# de los nodos (node pools "general-purpose" y "system"). Por eso no hay un
# recurso aws_instance ni un grupo de nodos administrado en este código.
resource "aws_eks_cluster" "online_boutique" {
  name     = var.name
  version  = var.kubernetes_version
  role_arn = var.cluster_role_arn

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Requerido por EKS Auto Mode: los add-ons básicos los gestiona AWS.
  bootstrap_self_managed_addons = false

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = var.node_role_arn
  }

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = "10.100.0.0/16"
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    subnet_ids              = data.aws_subnets.lab.ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  upgrade_policy {
    support_type = "STANDARD"
  }

  zonal_shift_config {
    enabled = true
  }
}

# Add-on de métricas instalado en el clúster (usado por kubectl top / HPA)
resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.online_boutique.name
  addon_name   = "metrics-server"
}

# 3. Registro de imágenes (Amazon ECR): un repositorio por microservicio.
# La lista se centraliza en var.microservices y coincide con la matriz del
# workflow .github/workflows/ci.yml.
resource "aws_ecr_repository" "microservice" {
  for_each = toset(var.microservices)

  name                 = "${var.ecr_repository_prefix}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# 4. Backend remoto (S3 + DynamoDB para bloqueo de estado)
# Declarados en providers.tf. El bucket y la tabla se crearon manualmente
# antes de habilitar el backend; no se declaran aquí para evitar la
# dependencia circular de que Terraform cree el sitio donde guarda su estado.
