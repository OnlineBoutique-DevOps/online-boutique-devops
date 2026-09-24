# Archivo temporal para crear solo los repositorios ECR
# Esto nos permite completar el Paso 1 sin problemas de IAM de EKS

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