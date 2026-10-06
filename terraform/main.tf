# =============================================================================
# Infraestructura Serverless:
#
#   Flutter -> API Gateway (HTTP API) -> Lambda (Spring Boot) -> Neon (PostgreSQL)
#                                           |
#                                           +-> S3 (archivos subidos)
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  function_name = "${var.project_name}-api"
  # Los nombres de bucket son globales en AWS: el numero de cuenta los hace unicos
  account_id = data.aws_caller_identity.current.account_id
}

# -----------------------------------------------------------------------------
# S3: bucket PRIVADO para los archivos que suben los usuarios.
# Nadie accede directamente: los archivos se leen siempre a traves de la API (con JWT).
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "files" {
  bucket = "${var.project_name}-files-${local.account_id}"

  # Proyecto academico: permite borrar el bucket con terraform destroy aunque tenga archivos
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "files" {
  bucket                  = aws_s3_bucket.files.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# S3: bucket para el paquete .zip de la Lambda.
# El zip pesa mas de 50 MB, el limite para subirlo directamente a Lambda.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-artifacts-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "lambda/api-springboot-lambda.zip"
  source = var.lambda_zip_path
  # Si el zip cambia, se vuelve a subir
  etag = filemd5(var.lambda_zip_path)
}

# -----------------------------------------------------------------------------
# IAM: rol que asume la Lambda y lo minimo que puede hacer.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = "${local.function_name}-role"

  # Solo el servicio Lambda puede usar este rol
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Escribir logs solo en su propio log group
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
      {
        # Leer, guardar y eliminar archivos solo dentro de uploads/ del bucket de archivos
        Sid      = "Files"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.files.arn}/uploads/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch: logs de la Lambda (lo que Spring imprime por consola).
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7
}

# -----------------------------------------------------------------------------
# Lambda: el backend Spring Boot.
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "api" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn

  runtime = "java17"
  # Clase que recibe los eventos de API Gateway (backend/.../lambda/StreamLambdaHandler)
  handler     = "com.example.api.infrastructure.lambda.StreamLambdaHandler::handleRequest"
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  # Codigo: el zip subido a S3. El hash hace que se actualice cuando cambia.
  s3_bucket        = aws_s3_object.lambda_zip.bucket
  s3_key           = aws_s3_object.lambda_zip.key
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  environment {
    variables = {
      # Base de datos Neon (valores secretos que llegan desde TF_VAR_* / GitHub Secrets)
      DATABASE_URL      = var.database_url
      DATABASE_USERNAME = var.database_username
      DATABASE_PASSWORD = var.database_password
      JWT_SECRET        = var.jwt_secret

      # Archivos en S3 en lugar de disco
      STORAGE   = "s3"
      S3_BUCKET = aws_s3_bucket.files.bucket

      # Cada instancia de Lambda atiende una peticion a la vez: 2 conexiones bastan
      DB_POOL_SIZE = "2"
      SHOW_SQL     = "false"

      # Recomendacion de AWS para Java: compila menos al arrancar -> arranque en frio mas rapido
      JAVA_TOOL_OPTIONS = "-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
    }
  }

  # El log group debe existir antes, para que tenga la retencion de 7 dias
  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy.lambda]
}

# -----------------------------------------------------------------------------
# API Gateway (HTTP API): URL publica que recibe las peticiones de Flutter.
# Todas las rutas (/auth/login, /api/users, /upload...) se envian a la Lambda,
# y Spring decide que controller responde.
# -----------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

# "$default" = cualquier metodo y cualquier ruta
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  # Limite de peticiones: protege la cuenta de costes inesperados
  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

# Permiso para que API Gateway pueda invocar la Lambda
resource "aws_lambda_permission" "apigateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
