import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/uploaded_file.dart';
import '../theme.dart';
import '../viewmodels/files_viewmodel.dart';
import 'common_widgets.dart';

/// Pestana Archivos: galeria con miniaturas de imagenes e iconos de documentos.
class FilesView extends StatelessWidget {
  const FilesView({super.key});

  Future<void> _upload(BuildContext context) async {
    final vm = context.read<FilesViewModel>();
    await Navigator.pushNamed(context, '/upload');
    vm.loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FilesViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: vm.loadFiles,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upload(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Subir archivo'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _filterChip(vm, FileFilter.all, 'Todos', vm.totalCount),
                _filterChip(vm, FileFilter.images, 'Imagenes', vm.imageCount),
                _filterChip(
                    vm, FileFilter.documents, 'Documentos', vm.documentCount),
              ],
            ),
          ),
          Expanded(child: _buildBody(context, vm)),
        ],
      ),
    );
  }

  Widget _filterChip(
      FilesViewModel vm, FileFilter value, String label, int count) {
    final selected = vm.filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        label: Text('$label  $count',
            style: TextStyle(color: selected ? Colors.white : AppColors.ink)),
        selected: selected,
        onSelected: (_) => vm.setFilter(value),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FilesViewModel vm) {
    if (vm.isLoading && vm.totalCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los archivos',
        message: vm.error,
        action: OutlinedButton(
            onPressed: vm.loadFiles, child: const Text('Reintentar')),
      );
    }
    if (vm.files.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        title: vm.totalCount == 0
            ? 'Todavia no hay archivos'
            : 'Nada en esta categoria',
        message: 'Sube imagenes, PDF, TXT, Word o Excel de hasta 10 MB.',
        action: FilledButton.icon(
          onPressed: () => _upload(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Subir archivo'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: vm.loadFiles,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .8,
        ),
        itemCount: vm.files.length,
        itemBuilder: (context, index) => _FileTile(file: vm.files[index]),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final UploadedFile file;

  const _FileTile({required this.file});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<FilesViewModel>();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, '/files/view', arguments: file),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.background,
                    child: file.isImage
                        ? FutureBuilder<Uint8List>(
                            future: vm.contentOf(file),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorBuilder: brokenImage);
                              }
                              if (snapshot.hasError) {
                                return brokenImage(
                                    context, snapshot.error!, null);
                              }
                              return const Center(
                                  child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)));
                            },
                          )
                        : Center(
                            child: FileTypeIcon(
                                contentType: file.contentType, size: 48)),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(fileTypeLabel(file.contentType),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(formatSize(file.size),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
