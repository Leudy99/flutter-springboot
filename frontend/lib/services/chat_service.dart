import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/chat_message.dart';

/// Conexion WebSocket con el chat del backend (ws://HOST/ws/chat).
/// A diferencia de ApiClient (HTTP: una peticion, una respuesta), aqui la
/// conexion queda abierta y el servidor envia los mensajes cuando llegan.
class ChatService {
  WebSocketChannel? _channel;

  /// Abre la conexion, se registra con el nombre y devuelve el flujo de mensajes.
  /// Lanza una excepcion si el servidor no responde.
  Future<Stream<ChatMessage>> connect(String username) async {
    final channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
    await channel.ready; // espera a que el servidor acepte la conexion
    _channel = channel;

    _send({'type': 'CONNECT', 'username': username});

    return channel.stream.map((data) =>
        ChatMessage.fromJson(jsonDecode(data as String) as Map<String, dynamic>));
  }

  void sendMessage(String message) =>
      _send({'type': 'MESSAGE', 'message': message});

  void _send(Map<String, String> payload) =>
      _channel?.sink.add(jsonEncode(payload));

  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }
}
