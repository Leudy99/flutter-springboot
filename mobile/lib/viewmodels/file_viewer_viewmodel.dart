import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/uploaded_file.dart';
import '../repositories/file_repository.dart';
import '../services/api_client.dart';

/// Estado del visor de un archivo: descarga su contenido del backend.
class FileViewerViewModel extends ChangeNotifier {
  final FileRepository _fileRepository;
  final UploadedFile file;

  FileViewerViewModel(this._fileRepository, this.file);

  bool isLoading = false;
  String? error;
  Uint8List? content;

  /// Texto del archivo si es .txt
  String? get text => content == null || !file.isText
      ? null
      : utf8.decode(content!, allowMalformed: true);

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      content = await _fileRepository.download(file);
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
