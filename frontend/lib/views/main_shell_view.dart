import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/files_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/user_list_viewmodel.dart';
import 'files_view.dart';
import 'home_view.dart';
import 'user_list_view.dart';

/// Estructura principal tras el login: barra inferior con Inicio, Usuarios y Archivos.
/// Cada pestana conserva su estado (IndexedStack) y se recarga al volver a ella.
class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView> {
  int _index = 0;

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    switch (index) {
      case 0:
        context.read<HomeViewModel>().refresh();
      case 1:
        context.read<UserListViewModel>().loadUsers();
      case 2:
        context.read<FilesViewModel>().loadFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeView(onOpenTab: _select),
          const UserListView(),
          const FilesView(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFDCE1E7))),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Usuarios',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Archivos',
            ),
          ],
        ),
      ),
    );
  }
}
