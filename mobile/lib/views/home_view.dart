import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../viewmodels/home_viewmodel.dart';
import 'common_widgets.dart';

/// Pestana Inicio: resumen del equipo, demostracion de Future.wait() y archivos recientes.
class HomeView extends StatelessWidget {
  /// Cambia de pestana en la barra inferior (1 = Usuarios, 2 = Archivos).
  final ValueChanged<int> onOpenTab;

  const HomeView({super.key, required this.onOpenTab});

  Future<void> _logout(BuildContext context) async {
    await context.read<HomeViewModel>().logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  /// Abre una pantalla y al volver recarga el resumen.
  Future<void> _open(BuildContext context, String route) async {
    final vm = context.read<HomeViewModel>();
    await Navigator.pushNamed(context, route);
    vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();

    // Iconos claros en la barra de estado sobre la cabecera oscura
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(vm: vm, onLogout: () => _logout(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _open(context, '/users/form'),
                            icon: const Icon(Icons.person_add_alt, size: 20),
                            label: const Text('Nuevo usuario'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _open(context, '/upload'),
                            icon: const Icon(Icons.upload_file, size: 20),
                            label: const Text('Subir archivo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _ConcurrencyPanel(vm: vm),
                    const SizedBox(height: 24),
                    SectionHeader('Archivos recientes',
                        actionLabel: 'Ver todos', onAction: () => onOpenTab(2)),
                    _RecentFiles(vm: vm),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera tinta con el perfil y las cifras principales.
class _Header extends StatelessWidget {
  final HomeViewModel vm;
  final VoidCallback onLogout;

  const _Header({required this.vm, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final profile = vm.profile;
    final firstName = profile?.name.split(' ').first ?? '';

    return Container(
      color: AppColors.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                      name: profile?.name ?? '?', radius: 24, inverted: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile == null ? 'Cargando...' : 'Hola, $firstName',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(profile?.email ?? '',
                            style: const TextStyle(color: Color(0xFFB8C2CE)),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (_) => onLogout(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'logout',
                        child: ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Cerrar sesion'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    _Figure(value: '${vm.users.length}', label: 'Usuarios'),
                    const _FigureDivider(),
                    _Figure(value: '${vm.files.length}', label: 'Archivos'),
                    const _FigureDivider(),
                    _Figure(
                        value: formatSize(vm.storageBytes),
                        label: 'Espacio usado'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String value;
  final String label;

  const _Figure({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600)),
          Text(label,
              style: const TextStyle(color: Color(0xFFB8C2CE), fontSize: 13)),
        ],
      ),
    );
  }
}

class _FigureDivider extends StatelessWidget {
  const _FigureDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: const Color(0xFF3A4757),
      );
}

/// Demostracion de concurrencia: pide perfil, usuarios y archivos
/// en paralelo (Future.wait) o en secuencia, y compara el tiempo total.
class _ConcurrencyPanel extends StatelessWidget {
  final HomeViewModel vm;

  const _ConcurrencyPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = vm.concurrentMs;
    final s = vm.sequentialMs;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Carga de datos',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Pide perfil, usuarios y archivos a la vez o una tras otra.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: vm.isLoading ? null : vm.loadConcurrent,
                    child: const Text('En paralelo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: vm.isLoading ? null : vm.loadSequential,
                    child: const Text('En secuencia'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (vm.isLoading)
              const LinearProgressIndicator()
            else if (vm.error != null)
              ErrorBanner(vm.error!)
            else
              Row(
                children: [
                  _Time('En paralelo', c, AppColors.teal, AppColors.tealSoft),
                  const SizedBox(width: 12),
                  _Time(
                      'En secuencia', s, AppColors.amber, AppColors.amberSoft),
                ],
              ),
            if (!vm.isLoading && c != null && s != null && s > c) ...[
              const SizedBox(height: 10),
              Text(
                'En paralelo fue ${((s - c) * 100 / s).toStringAsFixed(0)} % mas rapido.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tiempo total de un modo, o un guion si todavia no se midio.
class _Time extends StatelessWidget {
  final String label;
  final int? ms;
  final Color color;
  final Color background;

  const _Time(this.label, this.ms, this.color, this.background);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 13)),
            Text(ms == null ? '-' : '$ms ms',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

/// Los 3 archivos mas recientes.
class _RecentFiles extends StatelessWidget {
  final HomeViewModel vm;

  const _RecentFiles({required this.vm});

  @override
  Widget build(BuildContext context) {
    final recent = vm.files.take(3).toList();
    if (recent.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.folder_open_outlined),
          title: const Text('Todavia no hay archivos'),
          subtitle:
              const Text('Sube una imagen o un documento para verlo aqui.'),
          onTap: () => Navigator.pushNamed(context, '/upload'),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                    child: FileTypeIcon(
                        contentType: recent[i].contentType, size: 24)),
              ),
              title: Text(recent[i].originalName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${fileTypeLabel(recent[i].contentType)}, ${formatSize(recent[i].size)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/files/view',
                  arguments: recent[i]),
            ),
          ],
        ],
      ),
    );
  }
}
