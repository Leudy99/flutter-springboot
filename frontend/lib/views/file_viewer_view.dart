import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../viewmodels/file_viewer_viewmodel.dart';
import 'common_widgets.dart';

/// Visor de un archivo subido:
/// - imagen: con zoom (pellizcar)
/// - PDF: paginas con pdfrx
/// - TXT: texto
/// - Word / Excel: datos del archivo (no hay vista previa)
class FileViewerView extends StatelessWidget {
  const FileViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FileViewerViewModel>();
    final file = vm.file;

    return Scaffold(
      appBar: AppBar(
        title: Text(file.originalName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Informacion',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfo(context, vm),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: vm.isDeleting ? null : () => _confirmDelete(context, vm),
          ),
        ],
      ),
      body: _buildBody(context, vm),
    );
  }

  /// Pide confirmacion, elimina y vuelve atras devolviendo true
  /// (la pantalla anterior recarga la lista).
  Future<void> _confirmDelete(
      BuildContext context, FileViewerViewModel vm) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text(
            '"${vm.file.originalName}" se borrara del servidor. Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await vm.delete();
    messenger
        .showSnackBar(SnackBar(content: Text(error ?? 'Archivo eliminado')));
    if (error == null) navigator.pop(true);
  }

  Widget _buildBody(BuildContext context, FileViewerViewModel vm) {
    final file = vm.file;

    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No se pudo abrir',
        message: vm.error,
        action:
            OutlinedButton(onPressed: vm.load, child: const Text('Reintentar')),
      );
    }
    final content = vm.content;
    if (content == null) return const SizedBox();

    if (file.isImage) {
      return Container(
        color: Colors.black,
        child: InteractiveViewer(
          maxScale: 5,
          child:
              Center(child: Image.memory(content, errorBuilder: brokenImage)),
        ),
      );
    }
    if (file.isPdf) {
      return PdfViewer.data(content, sourceName: file.storedName);
    }
    if (file.isText) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(vm.text ?? '',
                style: const TextStyle(fontFamily: 'monospace')),
          ),
        ),
      );
    }
    return EmptyState(
      icon: Icons.visibility_off_outlined,
      title: 'Vista previa no disponible',
      message: 'El archivo esta guardado en el servidor. La app muestra '
          'imagenes, PDF y TXT; Word y Excel no tienen vista previa.',
      action: FileTypeIcon(contentType: file.contentType, size: 64),
    );
  }

  void _showInfo(BuildContext context, FileViewerViewModel vm) {
    final file = vm.file;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: FileTypeIcon(contentType: file.contentType, size: 32),
              title: Text(file.originalName),
              subtitle: Text(file.contentType),
            ),
            _info('Tipo', fileTypeLabel(file.contentType)),
            _info('Tamano', formatSize(file.size)),
            _info('Fecha',
                file.uploadedAt == null ? '-' : formatDate(file.uploadedAt)),
            _info('Nombre en el servidor', file.storedName),
            _info('URL', file.url),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) => ListTile(
        dense: true,
        title: Text(label),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(value,
              textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
        ),
      );
}
