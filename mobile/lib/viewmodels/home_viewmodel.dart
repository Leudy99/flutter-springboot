import 'package:flutter/foundation.dart';

import '../models/request_timing.dart';
import '../models/uploaded_file.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/file_repository.dart';
import '../repositories/user_repository.dart';
import '../services/api_client.dart';

/// Estado de la pantalla Home.
///
/// Aqui esta la DEMOSTRACION DE CONCURRENCIA:
/// - loadConcurrent(): lanza 3 peticiones a la vez y espera con Future.wait()
/// - loadSequential(): las mismas 3 peticiones, una detras de otra (para comparar)
class HomeViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  final FileRepository _fileRepository;
  final AuthRepository _authRepository;

  HomeViewModel(
      this._userRepository, this._fileRepository, this._authRepository);

  bool isLoading = false;
  String? error;

  User? profile;
  List<User> users = [];
  List<UploadedFile> files = [];

  /// Espacio ocupado por todos los archivos subidos.
  int get storageBytes => files.fold(0, (sum, f) => sum + f.size);

  /// Resultado de la ultima carga, para dibujar la linea de tiempo.
  bool? lastWasConcurrent;
  int totalMs = 0;
  final List<RequestTiming> timings = [];

  /// Ultimo tiempo total de cada modo, para compararlos.
  int? concurrentMs;
  int? sequentialMs;

  static const _order = ['Perfil', 'Usuarios', 'Archivos'];

  /// En localhost cada respuesta tarda pocos ms y casi no se nota la diferencia.
  /// En la demo se anaden 300 ms a cada peticion para imitar una red movil real.
  static const simulatedLatency = Duration(milliseconds: 300);

  /// Reloj de la carga actual: marca cuando empieza cada peticion.
  final _clock = Stopwatch();

  /// Recarga el resumen (al entrar, al volver a la pestana o al deslizar hacia abajo).
  /// Tambien usa Future.wait(), pero sin latencia simulada ni medicion,
  /// para no mezclar la carga normal con la demostracion.
  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _userRepository.getProfile(),
        _userRepository.getUsers(),
        _fileRepository.getFiles(),
      ]);
      profile = results[0] as User;
      users = results[1] as List<User>;
      files = results[2] as List<UploadedFile>;
      error = null;
    } catch (e) {
      error = apiErrorMessage(e);
    }
    notifyListeners();
  }

  /// CONCURRENTE: las 3 peticiones empiezan al mismo tiempo.
  /// Al crear la lista, cada Future ya esta en marcha; Future.wait()
  /// espera a que terminen todas. Tiempo total ~ la peticion mas lenta.
  Future<void> loadConcurrent() async {
    await _load(concurrent: true, () async {
      final results = await Future.wait([
        _timed('Perfil', _userRepository.getProfile),
        _timed('Usuarios', _userRepository.getUsers),
        _timed('Archivos', _fileRepository.getFiles),
      ]);

      // Los resultados llegan en el mismo orden de la lista
      profile = results[0] as User;
      users = results[1] as List<User>;
      files = results[2] as List<UploadedFile>;
    });
  }

  /// SECUENCIAL: cada peticion espera a que termine la anterior.
  /// Tiempo total ~ suma de las 3 peticiones.
  Future<void> loadSequential() async {
    await _load(concurrent: false, () async {
      profile = await _timed('Perfil', _userRepository.getProfile);
      users = await _timed('Usuarios', _userRepository.getUsers);
      files = await _timed('Archivos', _fileRepository.getFiles);
    });
  }

  Future<void> logout() => _authRepository.logout();

  /// Ejecuta una peticion y registra cuando empieza y cuanto tarda.
  /// Antes de enviarla espera [simulatedLatency], como haria una red movil.
  Future<T> _timed<T>(String label, Future<T> Function() request) async {
    final start = _clock.elapsedMilliseconds;
    await Future.delayed(simulatedLatency);
    final result = await request();
    timings
        .add(RequestTiming(label, start, _clock.elapsedMilliseconds - start));
    return result;
  }

  Future<void> _load(Future<void> Function() action,
      {required bool concurrent}) async {
    isLoading = true;
    error = null;
    timings.clear();
    notifyListeners();

    _clock
      ..reset()
      ..start();
    try {
      await action();
      totalMs = _clock.elapsedMilliseconds;
      // Mostrar siempre en el mismo orden (llegan en el orden en que terminan)
      timings.sort(
          (a, b) => _order.indexOf(a.label).compareTo(_order.indexOf(b.label)));
      lastWasConcurrent = concurrent;
      if (concurrent) {
        concurrentMs = totalMs;
      } else {
        sequentialMs = totalMs;
      }
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      _clock.stop();
      isLoading = false;
      notifyListeners();
    }
  }
}
