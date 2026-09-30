import '../models/user.dart';
import 'api_client.dart';

/// Peticiones HTTP del CRUD de usuarios (/api/users). Requieren JWT.
class UserService {
  final ApiClient _api;

  UserService(this._api);

  Future<List<User>> getUsers() async {
    final response = await _api.dio.get('/api/users');
    return (response.data as List)
        .map((json) => User.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<User> getUser(int id) async {
    final response = await _api.dio.get('/api/users/$id');
    return User.fromJson(response.data);
  }

  /// Perfil del usuario autenticado (el backend lo saca del JWT).
  Future<User> getProfile() async {
    final response = await _api.dio.get('/api/users/me');
    return User.fromJson(response.data);
  }

  Future<User> createUser(String name, String email, String password) async {
    final response = await _api.dio.post('/api/users', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    return User.fromJson(response.data);
  }

  /// Si password es null, el backend conserva la contrasena actual.
  Future<User> updateUser(
      int id, String name, String email, String? password) async {
    final response = await _api.dio.put('/api/users/$id', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    return User.fromJson(response.data);
  }

  Future<void> deleteUser(int id) async {
    await _api.dio.delete('/api/users/$id');
  }
}
