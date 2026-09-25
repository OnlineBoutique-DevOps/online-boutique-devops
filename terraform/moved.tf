# Renombre de los repositorios ECR: de 13 recursos individuales a un único
# recurso con for_each. Estos bloques indican a Terraform que actualice las
# direcciones en el estado en lugar de destruir y recrear los repositorios
# (que contienen las imágenes desplegadas en producción).

moved {
  from = aws_ecr_repository.ad_service
  to   = aws_ecr_repository.microservice["adservice"]
}

moved {
  from = aws_ecr_repository.cart_service
  to   = aws_ecr_repository.microservice["cartservice"]
}

moved {
  from = aws_ecr_repository.checkout_service
  to   = aws_ecr_repository.microservice["checkoutservice"]
}

moved {
  from = aws_ecr_repository.currency_service
  to   = aws_ecr_repository.microservice["currencyservice"]
}

moved {
  from = aws_ecr_repository.email_service
  to   = aws_ecr_repository.microservice["emailservice"]
}

moved {
  from = aws_ecr_repository.frontend
  to   = aws_ecr_repository.microservice["frontend"]
}

moved {
  from = aws_ecr_repository.load_generator
  to   = aws_ecr_repository.microservice["loadgenerator"]
}

moved {
  from = aws_ecr_repository.payment_service
  to   = aws_ecr_repository.microservice["paymentservice"]
}

moved {
  from = aws_ecr_repository.product_catalog_service
  to   = aws_ecr_repository.microservice["productcatalogservice"]
}

moved {
  from = aws_ecr_repository.recommendation_service
  to   = aws_ecr_repository.microservice["recommendationservice"]
}

moved {
  from = aws_ecr_repository.review_service
  to   = aws_ecr_repository.microservice["reviewservice"]
}

moved {
  from = aws_ecr_repository.shipping_service
  to   = aws_ecr_repository.microservice["shippingservice"]
}

moved {
  from = aws_ecr_repository.shopping_assistant_service
  to   = aws_ecr_repository.microservice["shoppingassistantservice"]
}
