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
