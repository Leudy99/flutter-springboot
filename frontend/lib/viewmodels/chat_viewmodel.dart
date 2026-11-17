import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

enum ChatStatus { disconnected, connecting, connected }

/// Estado de la pantalla "Chat" (WebSocket).
class ChatViewModel extends ChangeNotifier {
  final ChatService _service;

  ChatViewModel(this._service);

  ChatStatus status = ChatStatus.disconnected;
  final List<ChatMessage> messages = [];
  String username = '';
  String? error;

  StreamSubscription<ChatMessage>? _subscription;
  bool _disposed = false;

  bool get isConnected => status == ChatStatus.connected;

  Future<void> connect(String name) async {
    if (status != ChatStatus.disconnected) return;
    username = name.trim();
    error = null;
    // Cada conexion empieza con la pantalla limpia: lo de la sesion anterior
    // (otro nombre) ya no se muestra ni se confunde con los mensajes propios.
    messages.clear();
    status = ChatStatus.connecting;
    _notify();
    try {
      final stream = await _service.connect(username);
      if (_disposed) {
        await _service.close();
        return;
      }
      status = ChatStatus.connected;
      _subscription = stream.listen(
        (message) {
          messages.add(message);
          _notify();
        },
        // El servidor cerro la conexion o se cayo la red
        onError: (_) => _lost('Se perdio la conexion con el servidor.'),
        onDone: () => _lost('Se perdio la conexion con el servidor.'),
      );
    } catch (_) {
      status = ChatStatus.disconnected;
      error = 'No se pudo conectar al chat. Comprueba que el backend local o '
          'de Kubernetes este activo (el chat no funciona en AWS Lambda).';
    }
    _notify();
  }

  void send(String text) {
    final message = text.trim();
    if (!isConnected || message.isEmpty) return;
    _service.sendMessage(message);
  }

  /// El usuario cierra el chat: el servidor avisa a los demas.
  Future<void> disconnect() async {
    if (status == ChatStatus.disconnected) return;
    await _subscription?.cancel();
    _subscription = null;
    await _service.close();
    status = ChatStatus.disconnected;
    messages.add(ChatMessage.local('Te has desconectado.'));
    _notify();
  }

  void _lost(String reason) {
    if (status != ChatStatus.connected) return;
    _subscription = null;
    status = ChatStatus.disconnected;
    error = reason;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _service.close();
    super.dispose();
  }
}
