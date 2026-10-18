# Valores NO sensibles. Los secretos se pasan con variables TF_VAR_* (ver variables.tf).
aws_region   = "us-east-2"
project_name = "flutter-springboot"

# Notificaciones (nombres, no sensibles)
notification_topic_name  = "notification-topic"
notification_queue_name  = "notification-queue"
notification_lambda_name = "notification-lambda"
# email_sender NO va aqui: llega desde el GitHub Secret EMAIL_SENDER (TF_VAR_email_sender)

# Limite de API Gateway. 10/20 es la proteccion de costes con la que se desplego.
# Limite de peticiones de API Gateway. Durante las pruebas de carga se elevo temporalmente
# (ver docs/INFORME_PRUEBAS_CARGA.md) y se restauro a estos valores.
api_throttle_rate  = 10000
api_throttle_burst = 5000
