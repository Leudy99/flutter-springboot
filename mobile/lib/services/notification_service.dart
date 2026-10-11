import 'api_client.dart';

/// Peticion HTTP de notificaciones: POST /notifications/send. Requiere JWT.
///
/// El backend no envia el correo: publica un mensaje en SNS y responde.
/// El correo llega despues (SNS -> SQS -> notification-lambda -> SES).
class NotificationService {
  final ApiClient _api;

  NotificationService(this._api);

  Future<void> send(String email, String subject, String message) async {
    await _api.dio.post('/notifications/send', data: {
      'email': email,
      'subject': subject,
      'message': message,
    });
  }
}
