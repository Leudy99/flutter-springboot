import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../repositories/user_repository.dart';
import '../services/api_client.dart';

/// Estado de la pantalla de listado de usuarios.
class UserListViewModel extends ChangeNotifier {
  final UserRepository _userRepository;

  UserListViewModel(this._userRepository);

  bool isLoading = false;
  String? error;
  List<User> users = [];
  String query = '';

  /// Usuarios que coinciden con la busqueda (por nombre o email).
  List<User> get filteredUsers {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }

  void search(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> loadUsers() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      users = await _userRepository.getUsers();
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Devuelve null si se elimino bien, o el mensaje de error.
  Future<String?> deleteUser(User user) async {
    try {
      await _userRepository.deleteUser(user.id);
      users.removeWhere((u) => u.id == user.id);
      notifyListeners();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }
}
