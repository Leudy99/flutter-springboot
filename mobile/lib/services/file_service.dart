import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/picked_file.dart';
import '../models/uploaded_file.dart';
import 'api_client.dart';

/// Peticiones HTTP de archivos: POST /upload y GET /files.
class FileService {
  final ApiClient _api;

  FileService(this._api);

  /// Sube el archivo como multipart/form-data en el campo "file".
  /// [onProgress] recibe los bytes enviados y el total (onSendProgress de Dio).
  Future<UploadedFile> upload(
    PickedFile file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: DioMediaType.parse(file.mimeType),
      ),
    });

    final response = await _api.dio.post(
      '/upload',
      data: formData,
      onSendProgress: onProgress,
    );
    return UploadedFile.fromJson(response.data);
  }

  /// Descarga el contenido del archivo (GET /files/{storedName}) como bytes.
  /// Se usa Dio y no Image.network para que la peticion lleve el JWT.
  Future<Uint8List> download(UploadedFile file) async {
    final response = await _api.dio.get<List<int>>(
      file.url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  /// Elimina uno de mis archivos (DELETE /files/{id}).
  Future<void> deleteFile(int id) async {
    await _api.dio.delete('/files/$id');
  }

  /// Mis archivos (el backend solo devuelve los del usuario del token).
  Future<List<UploadedFile>> getFiles() async {
    final response = await _api.dio.get('/files');
    return (response.data as List)
        .map((json) => UploadedFile.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
