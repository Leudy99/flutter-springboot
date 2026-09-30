import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/uploaded_file.dart';
import 'repositories/auth_repository.dart';
import 'repositories/file_repository.dart';
import 'repositories/user_repository.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/file_service.dart';
import 'services/token_storage.dart';
import 'services/user_service.dart';
import 'theme.dart';
import 'viewmodels/file_viewer_viewmodel.dart';
import 'viewmodels/files_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/login_viewmodel.dart';
import 'viewmodels/upload_viewmodel.dart';
import 'viewmodels/user_form_viewmodel.dart';
import 'viewmodels/user_list_viewmodel.dart';
import 'views/file_viewer_view.dart';
import 'views/main_shell_view.dart';
import 'views/login_view.dart';
import 'views/upload_view.dart';
import 'views/user_form_view.dart';

/// Permite navegar desde fuera de un widget (p. ej. al recibir un 401).
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Services -> Repositories (se crean una sola vez y se comparten)
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage);
  final authRepository = AuthRepository(AuthService(apiClient), tokenStorage);
  final userRepository = UserRepository(UserService(apiClient));
  final fileRepository = FileRepository(FileService(apiClient));

  // Token invalido o expirado -> volver al login
  apiClient.onUnauthorized = () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  };

  final loggedIn = await authRepository.isLoggedIn();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: authRepository),
        Provider.value(value: userRepository),
        Provider.value(value: fileRepository),
      ],
      child: App(initialRoute: loggedIn ? '/home' : '/login'),
    ),
  );
}

class App extends StatelessWidget {
  final String initialRoute;

  const App({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      onGenerateInitialRoutes: (name) =>
          [_buildRoute(RouteSettings(name: name))],
      onGenerateRoute: _buildRoute,
    );
  }

  /// Rutas de la app. Cada pantalla recibe su propio ViewModel (View <-> ViewModel).
  static Route<dynamic> _buildRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      // Tras el login: barra inferior con Inicio, Usuarios y Archivos
      '/home' => MultiProvider(
          providers: [
            ChangeNotifierProvider(
                create: (ctx) => HomeViewModel(ctx.read<UserRepository>(),
                    ctx.read<FileRepository>(), ctx.read<AuthRepository>())
                  ..refresh()),
            ChangeNotifierProvider(
                create: (ctx) =>
                    UserListViewModel(ctx.read<UserRepository>())..loadUsers()),
            ChangeNotifierProvider(
                create: (ctx) =>
                    FilesViewModel(ctx.read<FileRepository>())..loadFiles()),
          ],
          child: const MainShellView(),
        ),
      '/users/form' => ChangeNotifierProvider(
          create: (ctx) => UserFormViewModel(
              ctx.read<UserRepository>(), settings.arguments as int?)
            ..loadUser(),
          child: const UserFormView(),
        ),
      '/files/view' => ChangeNotifierProvider(
          create: (ctx) => FileViewerViewModel(
              ctx.read<FileRepository>(), settings.arguments as UploadedFile)
            ..load(),
          child: const FileViewerView(),
        ),
      '/upload' => ChangeNotifierProvider(
          create: (ctx) => UploadViewModel(ctx.read<FileRepository>()),
          child: const UploadView(),
        ),
      _ => ChangeNotifierProvider(
          create: (ctx) => LoginViewModel(ctx.read<AuthRepository>()),
          child: const LoginView(),
        ),
    };
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
