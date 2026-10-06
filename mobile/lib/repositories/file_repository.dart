import 'dart:typed_data';

import '../models/picked_file.dart';
import '../models/uploaded_file.dart';
import '../services/file_service.dart';

/// Intermediario entre los ViewModels y FileService.
class FileRepository {
  final FileService _fileService;

  FileRepository(this._fileService);

  Future<UploadedFile> upload(
    PickedFile file, {
    void Function(int sent, int total)? onProgress,
  }) =>
      _fileService.upload(file, onProgress: onProgress);

  /// Lista de archivos, del mas reciente al mas antiguo.
  Future<List<UploadedFile>> getFiles() async {
    final files = await _fileService.getFiles();
    files.sort((a, b) => b.id.compareTo(a.id));
    return files;
  }

  Future<Uint8List> download(UploadedFile file) => _fileService.download(file);

  Future<void> delete(UploadedFile file) => _fileService.deleteFile(file.id);
}
