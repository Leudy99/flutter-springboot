import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../repositories/user_repository.dart';
import '../services/api_client.dart';

/// Estado del formulario de crear / editar usuario.
/// Si [userId] es null se crea un usuario; si no, se edita.
class UserFormViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  final int? userId;

  UserFormViewModel(this._userRepository, this.userId);

  bool get isEditing => userId != null;

  bool isLoading = false;
  bool isSaving = false;
  String? error;
  User? user; // datos actuales al editar (GET /api/users/{id})

  Future<void> loadUser() async {
    if (!isEditing) return;
    isLoading = true;
    notifyListeners();
    try {
      user = await _userRepository.getUser(userId!);
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Devuelve true si se guardo correctamente.
  Future<bool> save(String name, String email, String password) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      if (isEditing) {
        await _userRepository.updateUser(userId!, name, email, password);
      } else {
        await _userRepository.createUser(name, email, password);
      }
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
