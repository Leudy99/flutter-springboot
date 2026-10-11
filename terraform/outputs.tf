output "api_url" {
  description = "URL publica de API Gateway (la usa Flutter)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_function_name" {
  description = "Nombre de la Lambda"
  value       = aws_lambda_function.api.function_name
}

output "lambda_arn" {
  description = "ARN de la Lambda"
  value       = aws_lambda_function.api.arn
}

output "files_bucket" {
  description = "Bucket S3 de los archivos subidos"
  value       = aws_s3_bucket.files.bucket
}

output "sns_topic_arn" {
  description = "ARN del SNS Topic de notificaciones"
  value       = aws_sns_topic.notifications.arn
}

output "sqs_queue_url" {
  description = "URL de la cola SQS de notificaciones"
  value       = aws_sqs_queue.notifications.url
}

output "sqs_dlq_url" {
  description = "URL de la cola de errores (mensajes que fallaron 3 veces)"
  value       = aws_sqs_queue.notifications_dlq.url
}

output "notification_lambda_name" {
  description = "Nombre de la Lambda que envia los correos"
  value       = aws_lambda_function.notification.function_name
}

output "ses_sender" {
  description = "Remitente de los correos (debe estar verificado en SES)"
  value       = aws_sesv2_email_identity.sender.email_identity
}
