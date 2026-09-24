# 1. Crear red VPC para AWS
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name            = "online-boutique-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Tags requeridos para la integración de Kubernetes y Load Balancers
  public_subnet_tags = {
    "kubernetes.io/cluster/online-boutique-cluster" = "shared"
    "kubernetes.io/role/elb"                        = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/online-boutique-cluster" = "shared"
    "kubernetes.io/role/internal-elb"               = "1"
  }
}

# 2. Crear Clúster de Kubernetes (AWS EKS) - Ajustado para AWS Academy / Vocareum
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.2"

  cluster_name    = "online-boutique-cluster"
  cluster_version = "1.31" # Alineado con la versión real del clúster desplegado

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  create_cloudwatch_log_group    = false

  # Desactivar OIDC/IRSA para evitar el bloqueo de iam:CreateOpenIDConnectProvider en Vocareum
  enable_irsa = false

  # Reutilizar LabRole para el plano de control (Cluster)
  create_iam_role = false
  iam_role_arn    = "arn:aws:iam::414931564967:role/LabRole"

  # Desactivar la gestión del ConfigMap aws-auth
  manage_aws_auth_configmap = false

  eks_managed_node_groups = {
    nodes = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.medium"]
      ami_type       = "AL2_x86_64" # Alineado con la AMI original desplegada

      # Reutilizar LabRole para los nodos trabajadores (Node Group)
      create_iam_role = false
      iam_role_arn    = "arn:aws:iam::414931564967:role/LabRole"
    }
  }
}

# 3. Registro de imágenes (Amazon ECR) para todos los microservicios
resource "aws_ecr_repository" "review_service" {
  name                 = "online-boutique/reviewservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "ad_service" {
  name                 = "online-boutique/adservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "cart_service" {
  name                 = "online-boutique/cartservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "checkout_service" {
  name                 = "online-boutique/checkoutservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "currency_service" {
  name                 = "online-boutique/currencyservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "email_service" {
  name                 = "online-boutique/emailservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "online-boutique/frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "load_generator" {
  name                 = "online-boutique/loadgenerator"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "payment_service" {
  name                 = "online-boutique/paymentservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "product_catalog_service" {
  name                 = "online-boutique/productcatalogservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "recommendation_service" {
  name                 = "online-boutique/recommendationservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "shipping_service" {
  name                 = "online-boutique/shippingservice"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 4. Recursos para Backend Remoto (DynamoDB para State Locking)
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "online-boutique-tflocks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}