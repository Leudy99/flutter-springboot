/// Tipos de mensaje del chat (el servidor los envia en el campo "type").
enum ChatMessageType { connect, message, disconnect }

/// Mensaje del chat WebSocket. La fecha la pone el servidor.
class ChatMessage {
  final ChatMessageType type;
  final String username;
  final String message;
  final DateTime timestamp;

  const ChatMessage({
    required this.type,
    required this.username,
    required this.message,
    required this.timestamp,
  });

  /// Mensaje de sistema creado en el propio cliente (por ejemplo, "Te has desconectado").
  factory ChatMessage.local(String message) => ChatMessage(
        type: ChatMessageType.disconnect,
        username: '',
        message: message,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      type: switch (json['type']) {
        'CONNECT' => ChatMessageType.connect,
        'DISCONNECT' => ChatMessageType.disconnect,
        _ => ChatMessageType.message,
      },
      username: json['username'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// true para "X se ha conectado / desconectado" (no es un mensaje de un usuario).
  bool get isSystem => type != ChatMessageType.message;
}
