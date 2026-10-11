import '../services/notification_service.dart';

/// Intermediario entre el ViewModel de notificaciones y NotificationService.
class NotificationRepository {
  final NotificationService _notificationService;

  NotificationRepository(this._notificationService);

  Future<void> send(String email, String subject, String message) =>
      _notificationService.send(email.trim(), subject.trim(), message.trim());
}
