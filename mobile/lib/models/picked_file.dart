import 'dart:typed_data';

/// Archivo elegido en el dispositivo, antes de subirlo.
/// Se guardan los bytes para poder mostrar el preview y enviarlo por multipart.
class PickedFile {
  /// Extension -> tipo MIME. Son los mismos tipos que acepta el backend.
  static const Map<String, String> mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  static List<String> get allowedExtensions => mimeTypes.keys.toList();

  final String name;
  final Uint8List bytes;

  const PickedFile({required this.name, required this.bytes});

  int get size => bytes.length;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  String get mimeType => mimeTypes[extension] ?? 'application/octet-stream';

  bool get isImage => mimeType.startsWith('image/');
}
