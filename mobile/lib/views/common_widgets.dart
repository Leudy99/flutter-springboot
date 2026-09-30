import 'package:flutter/material.dart';

import '../theme.dart';

/// Widgets pequenos reutilizados por varias pantallas.

String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatDate(DateTime? date) {
  if (date == null) return '';
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Circulo con las iniciales del usuario.
class UserAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final bool inverted; // true = sobre fondo oscuro

  const UserAvatar({
    super.key,
    required this.name,
    this.radius = 22,
    this.inverted = false,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.isEmpty ? '?' : parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: inverted ? Colors.white : AppColors.tealSoft,
      child: Text(
        _initials,
        style: TextStyle(
          color: inverted ? AppColors.ink : AppColors.teal,
          fontWeight: FontWeight.w600,
          fontSize: radius * .72,
        ),
      ),
    );
  }
}

/// Icono segun el tipo de archivo.
class FileTypeIcon extends StatelessWidget {
  final String contentType;
  final double size;

  const FileTypeIcon({super.key, required this.contentType, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (contentType) {
      'application/pdf' => Icons.picture_as_pdf_outlined,
      'text/plain' => Icons.article_outlined,
      _
          when contentType.contains('word') ||
              contentType == 'application/msword' =>
        Icons.description_outlined,
      _ when contentType.contains('sheet') || contentType.contains('excel') =>
        Icons.table_chart_outlined,
      _ when contentType.startsWith('image/') => Icons.image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    final color = contentType == 'application/pdf'
        ? AppColors.error
        : contentType.startsWith('image/')
            ? AppColors.teal
            : AppColors.inkSoft;
    return Icon(icon, size: size, color: color);
  }
}

/// Etiqueta corta del tipo de archivo: PDF, PNG, TXT...
String fileTypeLabel(String contentType) => switch (contentType) {
      'application/pdf' => 'PDF',
      'text/plain' => 'TXT',
      'image/jpeg' => 'JPG',
      'image/png' => 'PNG',
      'image/gif' => 'GIF',
      'image/webp' => 'WEBP',
      _
          when contentType.contains('word') ||
              contentType == 'application/msword' =>
        'Word',
      _ when contentType.contains('sheet') || contentType.contains('excel') =>
        'Excel',
      _ => 'Archivo',
    };

/// Titulo de seccion con una accion opcional a la derecha.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Mensaje centrado para listas vacias o errores.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.inkSoft),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(message!,
                    style: const TextStyle(color: AppColors.inkSoft),
                    textAlign: TextAlign.center),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Caja con un mensaje de error.
class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }
}

/// Se muestra cuando los bytes no son una imagen valida.
Widget brokenImage(BuildContext context, Object error, StackTrace? stack) {
  return const Center(
    child:
        Icon(Icons.broken_image_outlined, size: 40, color: AppColors.inkSoft),
  );
}
