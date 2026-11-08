terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "online-boutique-tfstate-532727285947"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "online-boutique-tflocks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}