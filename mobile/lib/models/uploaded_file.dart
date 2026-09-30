/// Referencia de un archivo ya subido al backend (respuesta de POST /upload y GET /files).
class UploadedFile {
  final int id;
  final String originalName;
  final String storedName;
  final String contentType;
  final int size;
  final String url; // ruta relativa: /files/{storedName}
  final String? uploadedBy;
  final DateTime? uploadedAt;

  const UploadedFile({
    required this.id,
    required this.originalName,
    required this.storedName,
    required this.contentType,
    required this.size,
    required this.url,
    this.uploadedBy,
    this.uploadedAt,
  });

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';
  bool get isText => contentType == 'text/plain';

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      id: json['id'] as int,
      originalName: json['originalName'] as String,
      storedName: json['storedName'] as String,
      contentType: json['contentType'] as String,
      size: json['size'] as int,
      url: json['url'] as String,
      uploadedBy: json['uploadedBy'] as String?,
      uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? ''),
    );
  }
}
