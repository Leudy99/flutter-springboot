"""
notification-lambda: envia los correos de forma desacoplada.

    SNS Topic --> SQS Queue --> (esta Lambda) --> Amazon SES --> correo

AWS invoca esta funcion cuando hay mensajes en la cola SQS.
Cada mensaje trae un JSON con tres campos: email, subject y message
(lo publica el backend Spring Boot; ver NotificationService).

Si algo falla se lanza una excepcion: SQS no borra el mensaje y lo reintenta.
Tras 3 intentos fallidos pasa a la cola de errores (DLQ).
"""
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Remitente verificado en SES (lo define Terraform como variable de entorno)
SENDER = os.environ.get("EMAIL_SENDER", "")

REQUIRED_FIELDS = ("email", "subject", "message")

_ses = None


def get_ses():
    """Cliente de SES. Se crea una vez y se reutiliza mientras la Lambda esta caliente."""
    global _ses
    if _ses is None:
        import boto3  # ya viene incluido en el runtime de Lambda

        _ses = boto3.client("sesv2")
    return _ses


def lambda_handler(event, context):
    """Punto de entrada: AWS entrega aqui los mensajes de SQS en event["Records"]."""
    for record in event["Records"]:
        process_record(record)


def process_record(record):
    logger.info("Mensaje recibido desde SQS. messageId=%s", record["messageId"])

    try:
        data = parse_body(record["body"])
    except (ValueError, TypeError) as error:
        logger.error("Error al procesar mensaje %s: %s", record["messageId"], error)
        raise

    try:
        send_email(data["email"], data["subject"], data["message"])
    except Exception as error:
        logger.error("Error al enviar correo a %s: %s", data["email"], error)
        raise

    logger.info("Correo enviado correctamente. destinatario=%s", data["email"])


def parse_body(body):
    """Lee el JSON del mensaje y comprueba que traiga email, subject y message."""
    data = json.loads(body)

    # Si SNS entrego el mensaje dentro de su "sobre", el JSON original esta en "Message"
    if isinstance(data, dict) and "TopicArn" in data and "Message" in data:
        data = json.loads(data["Message"])

    missing = [f for f in REQUIRED_FIELDS if not isinstance(data.get(f), str) or not data[f].strip()]
    if missing:
        raise ValueError("Faltan campos obligatorios: " + ", ".join(missing))

    return {field: data[field].strip() for field in REQUIRED_FIELDS}


def send_email(recipient, subject, message):
    """Envia el correo con Amazon SES. Las credenciales salen del rol IAM de la Lambda."""
    get_ses().send_email(
        FromEmailAddress=SENDER,
        Destination={"ToAddresses": [recipient]},
        Content={
            "Simple": {
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {"Text": {"Data": message, "Charset": "UTF-8"}},
            }
        },
    )
