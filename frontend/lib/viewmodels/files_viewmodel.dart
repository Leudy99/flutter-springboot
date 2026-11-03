import 'package:flutter/foundation.dart';

import '../models/uploaded_file.dart';
import '../repositories/file_repository.dart';
import '../services/api_client.dart';

enum FileFilter { all, images, documents }

/// Estado de la galeria de archivos subidos.
class FilesViewModel extends ChangeNotifier {
  final FileRepository _fileRepository;

  FilesViewModel(this._fileRepository);

  bool isLoading = false;
  String? error;
  List<UploadedFile> _files = [];
  FileFilter filter = FileFilter.all;

  /// Descargas ya iniciadas, para no pedir dos veces la misma miniatura.
  final Map<int, Future<Uint8List>> _contentCache = {};

  List<UploadedFile> get files => switch (filter) {
        FileFilter.all => _files,
        FileFilter.images => _files.where((f) => f.isImage).toList(),
        FileFilter.documents => _files.where((f) => !f.isImage).toList(),
      };

  int get imageCount => _files.where((f) => f.isImage).length;
  int get documentCount => _files.length - imageCount;
  int get totalCount => _files.length;

  void setFilter(FileFilter value) {
    filter = value;
    notifyListeners();
  }

  Future<void> loadFiles() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      _files = await _fileRepository.getFiles();
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Contenido de un archivo (con JWT). Se guarda para reutilizarlo.
  Future<Uint8List> contentOf(UploadedFile file) {
    return _contentCache.putIfAbsent(
        file.id, () => _fileRepository.download(file));
  }
}
