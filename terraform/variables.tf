# --- Configuracion general (valores en terraform.tfvars) ---

variable "aws_region" {
  description = "Region de AWS donde se despliega todo"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Prefijo de los nombres de los recursos"
  type        = string
  default     = "flutter-springboot"
}

variable "lambda_zip_path" {
  description = "Ruta del paquete de la Lambda (mvn -Plambda package)"
  type        = string
  default     = "../backend/target/api-springboot-lambda.zip"
}

variable "lambda_memory_mb" {
  description = "Memoria de la Lambda. Mas memoria = mas CPU = arranque en frio mas rapido"
  type        = number
  default     = 2048
}

variable "lambda_timeout_seconds" {
  description = "Tiempo maximo por peticion (API Gateway corta a los 30 s)"
  type        = number
  default     = 30
}

# --- Notificaciones por correo (SNS + SQS) ---

variable "notification_topic_name" {
  description = "Nombre del SNS Topic (se le antepone project_name)"
  type        = string
  default     = "notification-topic"
}

variable "notification_queue_name" {
  description = "Nombre de la cola SQS (se le antepone project_name)"
  type        = string
  default     = "notification-queue"
}

variable "notification_lambda_name" {
  description = "Nombre de la Lambda que envia los correos (se le antepone project_name)"
  type        = string
  default     = "notification-lambda"
}

variable "load_test_email_domains" {
  description = "Dominios de correo de PRUEBAS DE CARGA, separados por coma. A estos destinatarios notification-lambda no les envia correo"
  type        = string
  default     = "test.com"
}

# --- Limite de peticiones de API Gateway (proteccion de costes) ---

variable "api_throttle_rate" {
  description = "Peticiones por segundo que acepta API Gateway; las demas reciben 429"
  type        = number
  default     = 10
}

variable "api_throttle_burst" {
  description = "Rafaga maxima de peticiones de API Gateway"
  type        = number
  default     = 20
}

variable "email_sender" {
  description = "Correo remitente de las notificaciones (se verifica en SES). Llega desde TF_VAR_email_sender / GitHub Secret EMAIL_SENDER"
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$", var.email_sender))
    error_message = "email_sender debe ser un correo valido (ej: usuario@dominio.com)."
  }
}

# --- Secretos ---
# NO van en terraform.tfvars. Se pasan como variables de entorno:
#   TF_VAR_database_url, TF_VAR_database_username,
#   TF_VAR_database_password, TF_VAR_jwt_secret
# En GitHub Actions salen de GitHub Secrets.
# "sensitive = true" hace que Terraform no los muestre en plan/apply.

variable "database_url" {
  description = "URL JDBC de Neon, sin usuario ni clave"
  type        = string
  sensitive   = true
}

variable "database_username" {
  description = "Usuario de Neon"
  type        = string
  sensitive   = true
}

variable "database_password" {
  description = "Clave de Neon"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Clave para firmar los JWT (minimo 32 caracteres)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "jwt_secret debe tener al menos 32 caracteres."
  }
}
