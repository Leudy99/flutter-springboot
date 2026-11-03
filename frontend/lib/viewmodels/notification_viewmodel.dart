import 'package:flutter/foundation.dart';

import '../repositories/notification_repository.dart';
import '../services/api_client.dart';

/// Estado de la pantalla "Enviar notificacion".
class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository _notificationRepository;

  NotificationViewModel(this._notificationRepository);

  bool isSending = false;

  /// Resultado del ultimo envio: uno de los dos es null.
  String? successMessage;
  String? error;

  /// Devuelve true si el backend acepto el mensaje (ya esta publicado en SNS).
  Future<bool> send(String email, String subject, String message) async {
    isSending = true;
    successMessage = null;
    error = null;
    notifyListeners();
    try {
      await _notificationRepository.send(email, subject, message);
      successMessage = 'Mensaje enviado correctamente.';
      return true;
    } catch (e) {
      error = 'Error al enviar mensaje.\n${apiErrorMessage(e)}';
      return false;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }
}
