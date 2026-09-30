import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../theme.dart';
import '../viewmodels/user_list_viewmodel.dart';
import 'common_widgets.dart';

/// Pestana Usuarios: buscar, crear, editar y eliminar.
class UserListView extends StatelessWidget {
  const UserListView({super.key});

  /// Abre el formulario y recarga la lista si se guardaron cambios.
  Future<void> _openForm(BuildContext context, {int? userId}) async {
    final vm = context.read<UserListViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final saved =
        await Navigator.pushNamed(context, '/users/form', arguments: userId);
    if (saved == true) {
      vm.loadUsers();
      messenger.showSnackBar(SnackBar(
          content:
              Text(userId == null ? 'Usuario creado' : 'Cambios guardados')));
    }
  }

  Future<void> _confirmDelete(BuildContext context, User user) async {
    final vm = context.read<UserListViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
            '${user.name} ya no podra iniciar sesion. Esta accion no se puede deshacer.'),
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

    final error = await vm.deleteUser(user);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Usuario eliminado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserListViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: vm.loadUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo usuario'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: vm.search,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o correo',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(child: _buildList(context, vm)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, UserListViewModel vm) {
    if (vm.isLoading && vm.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar la lista',
        message: vm.error,
        action: OutlinedButton(
            onPressed: vm.loadUsers, child: const Text('Reintentar')),
      );
    }
    final users = vm.filteredUsers;
    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.person_search_outlined,
        title: vm.query.isEmpty ? 'Todavia no hay usuarios' : 'Sin resultados',
        message: vm.query.isEmpty
            ? 'Crea el primero con el boton "Nuevo usuario".'
            : 'Ningun usuario coincide con "${vm.query}".',
      );
    }
    return RefreshIndicator(
      onRefresh: vm.loadUsers,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              users.length == 1 ? '1 usuario' : '${users.length} usuarios',
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < users.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 72),
                  _UserRow(
                    user: users[i],
                    onOpen: () => _openForm(context, userId: users[i].id),
                    onDelete: () => _confirmDelete(context, users[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final User user;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _UserRow(
      {required this.user, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      leading: UserAvatar(name: user.name),
      title: Text(user.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis),
      subtitle: Text(user.email, overflow: TextOverflow.ellipsis),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        tooltip: 'Acciones',
        onSelected: (action) => action == 'edit' ? onOpen() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit_outlined), title: Text('Editar')),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title:
                    Text('Eliminar', style: TextStyle(color: AppColors.error))),
          ),
        ],
      ),
    );
  }
}
