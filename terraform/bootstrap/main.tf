# =============================================================================
# BOOTSTRAP: se ejecuta UNA sola vez, antes que la infraestructura principal.
#
# Crea el bucket S3 donde Terraform guarda su "estado" (la lista de recursos que
# ya creo). Asi el estado se comparte entre tu PC y GitHub Actions, y la pipeline
# no intenta crear otra vez recursos que ya existen.
#
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
# =============================================================================

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Prefijo de los nombres de los recursos"
  type        = string
  default     = "flutter-springboot"
}

provider "aws" {
  region = var.aws_region
}

# Numero de cuenta: hace unico el nombre del bucket (los nombres de S3 son globales)
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Evita borrar el estado por accidente con terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}

# Guarda versiones anteriores del estado por si algo sale mal
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# El estado puede contener datos sensibles: nunca publico
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  description = "Bucket del estado (se usa en terraform/provider.tf)"
  value       = aws_s3_bucket.tfstate.bucket
}
