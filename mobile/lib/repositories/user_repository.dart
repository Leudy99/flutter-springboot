import '../models/user.dart';
import '../services/user_service.dart';

/// Intermediario entre los ViewModels y UserService.
class UserRepository {
  final UserService _userService;

  UserRepository(this._userService);

  Future<List<User>> getUsers() => _userService.getUsers();

  Future<User> getUser(int id) => _userService.getUser(id);

  Future<User> getProfile() => _userService.getProfile();

  Future<User> createUser(String name, String email, String password) =>
      _userService.createUser(name, email, password);

  /// Una contrasena vacia se envia como null para que el backend la conserve.
  Future<User> updateUser(int id, String name, String email, String password) =>
      _userService.updateUser(
          id, name, email, password.isEmpty ? null : password);

  Future<void> deleteUser(int id) => _userService.deleteUser(id);
}
