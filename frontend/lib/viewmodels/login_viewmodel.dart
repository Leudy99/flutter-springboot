import 'package:flutter/foundation.dart';

import '../repositories/auth_repository.dart';
import '../services/api_client.dart';

/// Estado de la pantalla de login / registro.
class LoginViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  LoginViewModel(this._authRepository);

  bool isLoading = false;
  bool isRegisterMode = false;
  String? error;

  void toggleMode() {
    isRegisterMode = !isRegisterMode;
    error = null;
    notifyListeners();
  }

  /// Devuelve true si el login fue correcto (el JWT ya quedo guardado).
  Future<bool> login(String email, String password) {
    return _run(() => _authRepository.login(email, password));
  }

  /// Registra y luego inicia sesion con las mismas credenciales.
  Future<bool> register(String name, String email, String password) {
    return _run(() async {
      await _authRepository.register(name, email, password);
      await _authRepository.login(email, password);
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
