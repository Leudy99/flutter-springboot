import 'api_client.dart';

/// Peticiones HTTP de autenticacion: /auth/login y /auth/register.
class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  /// Devuelve el JWT.
  Future<String> login(String email, String password) async {
    final response = await _api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data['token'] as String;
  }

  Future<void> register(String name, String email, String password) async {
    await _api.dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
  }
}
