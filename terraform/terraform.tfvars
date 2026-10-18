# Valores NO sensibles. Los secretos se pasan con variables TF_VAR_* (ver variables.tf).
aws_region   = "us-east-2"
project_name = "flutter-springboot"

# Notificaciones (nombres, no sensibles)
notification_topic_name  = "notification-topic"
notification_queue_name  = "notification-queue"
notification_lambda_name = "notification-lambda"
# email_sender NO va aqui: llega desde el GitHub Secret EMAIL_SENDER (TF_VAR_email_sender)

# Limite de API Gateway. 10/20 es la proteccion de costes con la que se desplego.
# TEMPORAL: para las pruebas de carga se sube al maximo de la cuenta (10000 req/s, rafaga 5000)
# y al terminar se restaura a 10/20 (ver docs/INFORME_PRUEBAS_CARGA.md).
api_throttle_rate  = 10000
api_throttle_burst = 5000
