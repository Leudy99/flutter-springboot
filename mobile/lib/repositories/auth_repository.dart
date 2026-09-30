import '../services/auth_service.dart';
import '../services/token_storage.dart';

/// Intermediario entre los ViewModels y los services de autenticacion.
/// Decide que hacer con el JWT: guardarlo tras el login y borrarlo en el logout.
class AuthRepository {
  final AuthService _authService;
  final TokenStorage _tokenStorage;

  AuthRepository(this._authService, this._tokenStorage);

  Future<void> login(String email, String password) async {
    final token = await _authService.login(email, password);
    await _tokenStorage.saveToken(token);
  }

  Future<void> register(String name, String email, String password) {
    return _authService.register(name, email, password);
  }

  Future<bool> isLoggedIn() async => await _tokenStorage.getToken() != null;

  Future<void> logout() => _tokenStorage.clear();
}
