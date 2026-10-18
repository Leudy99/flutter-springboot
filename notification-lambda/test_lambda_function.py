"""
Pruebas de notification-lambda sin AWS: SES se sustituye por un objeto falso.
Ejecutar:  python -m unittest discover -s notification-lambda
"""
import json
import unittest

import lambda_function


class FakeSes:
    """Guarda lo que se "enviaria" (en AWS es Amazon SES)."""

    def __init__(self, fail=False):
        self.sent = []
        self.fail = fail

    def send_email(self, **kwargs):
        if self.fail:
            raise RuntimeError("SES no disponible")
        self.sent.append(kwargs)


def sqs_event(body, message_id="m-1"):
    """Evento tal como lo entrega SQS a Lambda."""
    return {"Records": [{"messageId": message_id, "body": body}]}


class NotificationLambdaTest(unittest.TestCase):
    def setUp(self):
        self.ses = FakeSes()
        lambda_function._ses = self.ses
        lambda_function.SENDER = "remitente@test.com"
        lambda_function.LOAD_TEST_DOMAINS = {"carga.test"}

    def test_envia_el_correo_con_los_tres_campos(self):
        body = json.dumps({"email": "ana@test.com", "subject": "Prueba SNS", "message": "Hola"})

        lambda_function.lambda_handler(sqs_event(body), None)

        self.assertEqual(len(self.ses.sent), 1)
        sent = self.ses.sent[0]
        self.assertEqual(sent["FromEmailAddress"], "remitente@test.com")
        self.assertEqual(sent["Destination"]["ToAddresses"], ["ana@test.com"])
        self.assertEqual(sent["Content"]["Simple"]["Subject"]["Data"], "Prueba SNS")
        self.assertEqual(sent["Content"]["Simple"]["Body"]["Text"]["Data"], "Hola")

    def test_acepta_el_sobre_de_sns(self):
        original = json.dumps({"email": "ana@test.com", "subject": "S", "message": "M"})
        sobre = json.dumps({"TopicArn": "arn:aws:sns:x", "Message": original})

        lambda_function.lambda_handler(sqs_event(sobre), None)

        self.assertEqual(self.ses.sent[0]["Destination"]["ToAddresses"], ["ana@test.com"])

    def test_falla_si_falta_un_campo_y_no_envia_nada(self):
        body = json.dumps({"email": "ana@test.com", "subject": "S"})

        with self.assertRaises(ValueError):
            lambda_function.lambda_handler(sqs_event(body), None)

        self.assertEqual(self.ses.sent, [])

    def test_falla_si_el_cuerpo_no_es_json(self):
        with self.assertRaises(ValueError):
            lambda_function.lambda_handler(sqs_event("esto no es json"), None)

    def test_si_ses_falla_lanza_el_error_para_que_sqs_reintente(self):
        lambda_function._ses = FakeSes(fail=True)
        body = json.dumps({"email": "ana@test.com", "subject": "S", "message": "M"})

        with self.assertRaises(RuntimeError):
            lambda_function.lambda_handler(sqs_event(body), None)

    def test_modo_de_carga_procesa_el_mensaje_pero_no_llama_a_ses(self):
        body = json.dumps({"email": "usuario@carga.test", "subject": "Prueba", "message": "Mensaje de carga"})

        lambda_function.lambda_handler(sqs_event(body), None)

        self.assertEqual(self.ses.sent, [])

    def test_modo_de_carga_tambien_valida_el_mensaje(self):
        body = json.dumps({"email": "usuario@carga.test", "subject": "Prueba"})

        with self.assertRaises(ValueError):
            lambda_function.lambda_handler(sqs_event(body), None)

    def test_un_correo_real_siempre_se_envia(self):
        body = json.dumps({"email": "real@gmail.com", "subject": "S", "message": "M"})

        lambda_function.lambda_handler(sqs_event(body), None)

        self.assertEqual(len(self.ses.sent), 1)


if __name__ == "__main__":
    unittest.main()
