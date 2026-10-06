terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Estado remoto en S3 (lo crea terraform/bootstrap una sola vez).
  # Asi tu PC y GitHub Actions trabajan sobre el mismo estado.
  # use_lockfile evita que dos ejecuciones modifiquen la infraestructura a la vez.
  backend "s3" {
    bucket       = "flutter-springboot-tfstate-477537077802"
    key          = "serverless/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  # Etiqueta comun en todos los recursos para identificarlos en la consola
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}
