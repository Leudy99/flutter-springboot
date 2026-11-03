import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/picked_file.dart';
import '../models/uploaded_file.dart';
import '../repositories/file_repository.dart';
import '../services/api_client.dart';

/// Estado de la pantalla de subida de archivos.
class UploadViewModel extends ChangeNotifier {
  final FileRepository _fileRepository;

  UploadViewModel(this._fileRepository);

  PickedFile? selectedFile; // archivo elegido (para el preview)
  bool isUploading = false;
  double progress = 0; // 0.0 - 1.0
  String? error;
  UploadedFile? uploadedFile; // respuesta del backend

  /// Abre el selector del sistema. [images] = true solo muestra imagenes.
  Future<void> pickFile({required bool images}) async {
    final files = await FilePicker.pickFiles(
      type: images ? FileType.image : FileType.custom,
      allowedExtensions: images ? null : PickedFile.allowedExtensions,
    );
    if (files.isEmpty) return; // el usuario cancelo

    final file = files.first;
    selectedFile = PickedFile(name: file.name, bytes: await file.readAsBytes());
    uploadedFile = null;
    progress = 0;
    error = null;
    notifyListeners();
  }

  Future<void> upload() async {
    final file = selectedFile;
    if (file == null) return;

    isUploading = true;
    progress = 0;
    error = null;
    notifyListeners();
    try {
      uploadedFile = await _fileRepository.upload(
        file,
        // Dio llama a este callback cada vez que envia un bloque de bytes
        onProgress: (sent, total) {
          if (total > 0) {
            progress = sent / total;
            notifyListeners();
          }
        },
      );
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }
}
