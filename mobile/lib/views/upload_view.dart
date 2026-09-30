import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/picked_file.dart';
import '../theme.dart';
import '../viewmodels/upload_viewmodel.dart';
import 'common_widgets.dart';

/// Seleccion de archivo, vista previa, subida multipart y progreso.
class UploadView extends StatelessWidget {
  const UploadView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UploadViewModel>();
    final file = vm.selectedFile;
    final done = vm.uploadedFile != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Subir archivo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: file == null ? const _Placeholder() : _Selected(file: file),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      vm.isUploading ? null : () => vm.pickFile(images: true),
                  icon: const Icon(Icons.image_outlined, size: 20),
                  label: Text(file == null ? 'Elegir imagen' : 'Otra imagen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      vm.isUploading ? null : () => vm.pickFile(images: false),
                  icon: const Icon(Icons.description_outlined, size: 20),
                  label: Text(
                      file == null ? 'Elegir documento' : 'Otro documento'),
                ),
              ),
            ],
          ),
          if (file != null && !done) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: vm.isUploading ? null : vm.upload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(vm.isUploading ? 'Subiendo...' : 'Subir archivo'),
            ),
          ],
          if (vm.isUploading || vm.progress > 0) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(done ? 'Subida completa' : 'Enviando al servidor',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${(vm.progress * 100).toStringAsFixed(0)} %',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: vm.progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
              ),
            ),
          ],
          if (vm.error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(vm.error!),
          ],
          if (done) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.teal),
                      SizedBox(width: 8),
                      Text('Archivo guardado en el servidor',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.teal)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Disponible en ${vm.uploadedFile!.url}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surface),
                          onPressed: () => Navigator.pushNamed(
                              context, '/files/view',
                              arguments: vm.uploadedFile),
                          child: const Text('Ver archivo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Listo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.cloud_upload_outlined, size: 56, color: AppColors.teal),
          SizedBox(height: 12),
          Text('Elige una imagen o un documento',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          SizedBox(height: 4),
          Text(
            'JPG, PNG, GIF, WEBP, PDF, TXT, Word o Excel, hasta 10 MB.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Vista previa local del archivo elegido.
class _Selected extends StatelessWidget {
  final PickedFile file;

  const _Selected({required this.file});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 240,
          color: AppColors.background,
          alignment: Alignment.center,
          child: file.isImage
              ? Image.memory(file.bytes,
                  fit: BoxFit.contain, errorBuilder: brokenImage)
              : FileTypeIcon(contentType: file.mimeType, size: 96),
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle:
              Text('${fileTypeLabel(file.mimeType)}, ${formatSize(file.size)}'),
        ),
      ],
    );
  }
}
