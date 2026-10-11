# =============================================================================
# Infraestructura Serverless:
#
#   Flutter -> API Gateway (HTTP API) -> Lambda (Spring Boot) -> Neon (PostgreSQL)
#                                           |
#                                           +-> S3 (archivos subidos)
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  function_name              = "${var.project_name}-api"
  notification_function_name = "${var.project_name}-${var.notification_lambda_name}"
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
      },
      {
        # Publicar notificaciones SOLO en el topic del proyecto (no puede leer ni borrar nada)
        Sid      = "Notifications"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.notifications.arn
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

      # Notificaciones: el backend publica en SNS (no envia el correo)
      NOTIFICATIONS = "sns"
      SNS_TOPIC_ARN = aws_sns_topic.notifications.arn

      # Cada instancia de Lambda atiende una peticion a la vez: 2 conexiones bastan
      DB_POOL_SIZE = "2"
      SHOW_SQL     = "false"
    }
  }

  # SnapStart: al publicar una version, AWS arranca Spring Boot una vez y guarda
  # una "foto" de la memoria. Cada instancia nueva se restaura desde esa foto
  # en ~1-2 s en lugar de arrancar Spring desde cero (~9 s).
  publish = true
  snap_start {
    apply_on = "PublishedVersions"
  }

  # El log group debe existir antes, para que tenga la retencion de 7 dias
  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy.lambda]
}

# Alias "live": apunta siempre a la ultima version publicada (la que tiene SnapStart).
# API Gateway invoca el alias, no la funcion "a secas".
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.api.function_name
  function_version = aws_lambda_function.api.version
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
  integration_uri        = aws_lambda_alias.live.invoke_arn
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
  qualifier     = aws_lambda_alias.live.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# =============================================================================
# NOTIFICACIONES POR CORREO: mensajeria desacoplada
#
#   Lambda principal --publica--> SNS Topic --suscripcion--> SQS Queue --> notification-lambda --> correo
#
# El backend solo publica el mensaje y responde. Quien envia el correo es otra
# Lambda, activada por la cola. Si el envio falla, el mensaje se reintenta
# y, tras 3 intentos, pasa a la cola de errores (DLQ).
# =============================================================================

# -----------------------------------------------------------------------------
# SNS: el "buzon de entrada". Quien publica aqui no sabe quien consume el mensaje.
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-${var.notification_topic_name}"
}

# -----------------------------------------------------------------------------
# SQS: cola de errores (DLQ). Guarda los mensajes que fallaron 3 veces,
# para poder revisarlos en lugar de perderlos.
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "notifications_dlq" {
  name                      = "${var.project_name}-${var.notification_queue_name}-dlq"
  message_retention_seconds = 1209600 # 14 dias
}

# -----------------------------------------------------------------------------
# SQS: cola principal. Guarda los mensajes hasta que notification-lambda los procese.
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "notifications" {
  name = "${var.project_name}-${var.notification_queue_name}"

  # Mientras notification-lambda procesa un mensaje, este se oculta para los demas.
  # AWS recomienda al menos 6 veces el timeout de la Lambda (30 s).
  visibility_timeout_seconds = 180
  message_retention_seconds  = 86400 # 1 dia: son avisos, no tiene sentido guardarlos mas

  # Reintentos: a la 3.a vez que falla el mismo mensaje, pasa a la DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notifications_dlq.arn
    maxReceiveCount     = 3
  })
}

# -----------------------------------------------------------------------------
# Permiso: SNS puede enviar mensajes a esta cola, pero SOLO desde nuestro topic.
# Sin esta politica, SQS rechaza los mensajes de SNS.
# -----------------------------------------------------------------------------
resource "aws_sqs_queue_policy" "notifications" {
  queue_url = aws_sqs_queue.notifications.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSnsToSendMessages"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notifications.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.notifications.arn }
      }
    }]
  })
}

# -----------------------------------------------------------------------------
# Suscripcion SNS -> SQS: todo lo que se publica en el topic llega a la cola.
# raw_message_delivery = el cuerpo del mensaje en SQS es directamente nuestro JSON
# {"email", "subject", "message"}, sin el sobre que SNS agrega por defecto.
# -----------------------------------------------------------------------------
resource "aws_sns_topic_subscription" "notifications_queue" {
  topic_arn            = aws_sns_topic.notifications.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.notifications.arn
  raw_message_delivery = true

  depends_on = [aws_sqs_queue_policy.notifications]
}

# -----------------------------------------------------------------------------
# SES: identidad del remitente. SES solo envia desde direcciones verificadas.
# Al crearla, AWS manda un correo con un enlace de verificacion a esa direccion.
#
# SES empieza en modo "sandbox": ademas del remitente, el DESTINATARIO tambien
# debe estar verificado (aws sesv2 create-email-identity --email-identity <correo>).
# -----------------------------------------------------------------------------
resource "aws_sesv2_email_identity" "sender" {
  email_identity = var.email_sender
}

# -----------------------------------------------------------------------------
# notification-lambda: la funcion que envia el correo. Es independiente de la
# Lambda principal: otro codigo (Python), otro rol y otros permisos.
# El codigo es un solo archivo; Terraform lo empaqueta en un zip.
# -----------------------------------------------------------------------------
data "archive_file" "notification_lambda" {
  type        = "zip"
  source_file = "${path.module}/../notification-lambda/lambda_function.py"
  output_path = "${path.module}/notification-lambda.zip"
}

resource "aws_cloudwatch_log_group" "notification_lambda" {
  name              = "/aws/lambda/${local.notification_function_name}"
  retention_in_days = 7
}

resource "aws_iam_role" "notification_lambda" {
  name = "${local.notification_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "notification_lambda" {
  name = "${local.notification_function_name}-policy"
  role = aws_iam_role.notification_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Escribir logs solo en su propio log group
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.notification_lambda.arn}:*"
      },
      {
        # Leer mensajes de SU cola y borrarlos al terminar (nada mas)
        Sid      = "ReadQueue"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.notifications.arn
      },
      {
        # Enviar correos solo con la identidad verificada del proyecto
        Sid      = "SendEmail"
        Effect   = "Allow"
        Action   = "ses:SendEmail"
        Resource = aws_sesv2_email_identity.sender.arn
      }
    ]
  })
}

resource "aws_lambda_function" "notification" {
  function_name = local.notification_function_name
  role          = aws_iam_role.notification_lambda.arn

  runtime     = "python3.12"
  handler     = "lambda_function.lambda_handler"
  memory_size = 128
  timeout     = 30

  filename         = data.archive_file.notification_lambda.output_path
  source_code_hash = data.archive_file.notification_lambda.output_base64sha256

  environment {
    variables = {
      EMAIL_SENDER = var.email_sender
    }
  }

  depends_on = [aws_cloudwatch_log_group.notification_lambda, aws_iam_role_policy.notification_lambda]
}

# -----------------------------------------------------------------------------
# Event Source Mapping: SQS -> notification-lambda.
# AWS vigila la cola y, cuando hay mensajes, invoca la Lambda automaticamente.
# No hay codigo de "polling" en el backend ni en la Lambda.
# batch_size = 1: un mensaje por invocacion (si falla, solo se reintenta ese).
# -----------------------------------------------------------------------------
resource "aws_lambda_event_source_mapping" "notifications" {
  event_source_arn = aws_sqs_queue.notifications.arn
  function_name    = aws_lambda_function.notification.arn
  batch_size       = 1

  depends_on = [aws_iam_role_policy.notification_lambda]
}
