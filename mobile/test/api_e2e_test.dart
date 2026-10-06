// Prueba de extremo a extremo: ViewModels -> Repositories -> Services -> backend real.
// Requiere un backend en marcha (AWS, o local con docker compose up). Ejecutar con:
//   flutter test --run-skipped --tags e2e test/api_e2e_test.dart             (backend de config.dart)
//   flutter test --run-skipped --tags e2e --dart-define=API_URL=http://localhost:8081 test/api_e2e_test.dart
@Tags(['e2e'])
library;

import 'dart:typed_data';

import 'package:flutter_app/models/picked_file.dart';
import 'package:flutter_app/repositories/auth_repository.dart';
import 'package:flutter_app/repositories/file_repository.dart';
import 'package:flutter_app/repositories/user_repository.dart';
import 'package:flutter_app/services/api_client.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/services/file_service.dart';
import 'package:flutter_app/services/token_storage.dart';
import 'package:flutter_app/services/user_service.dart';
import 'package:flutter_app/viewmodels/file_viewer_viewmodel.dart';
import 'package:flutter_app/viewmodels/files_viewmodel.dart';
import 'package:flutter_app/viewmodels/home_viewmodel.dart';
import 'package:flutter_app/viewmodels/login_viewmodel.dart';
import 'package:flutter_app/viewmodels/upload_viewmodel.dart';
import 'package:flutter_app/viewmodels/user_form_viewmodel.dart';
import 'package:flutter_app/viewmodels/user_list_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage);
  final authRepository = AuthRepository(AuthService(apiClient), tokenStorage);
  final userRepository = UserRepository(UserService(apiClient));
  final fileRepository = FileRepository(FileService(apiClient));

  var unauthorizedCalls = 0;
  apiClient.onUnauthorized = () => unauthorizedCalls++;

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final myEmail = 'e2e$stamp@test.com';

  test('login con credenciales incorrectas muestra error', () async {
    final vm = LoginViewModel(authRepository);
    final ok = await vm.login('noexiste@test.com', 'xxxxxx');
    expect(ok, isFalse);
    expect(vm.error, 'Email o contrasena incorrectos');
    expect(await tokenStorage.getToken(), isNull);
  });

  test('registro + login guarda el JWT', () async {
    final vm = LoginViewModel(authRepository);
    final ok = await vm.register('E2E', myEmail, '123456');
    expect(ok, isTrue, reason: vm.error);
    expect(await tokenStorage.getToken(), isNotNull);
  });

  test('Future.wait: carga concurrente y secuencial', () async {
    final vm = HomeViewModel(userRepository, fileRepository, authRepository);

    await vm.loadConcurrent();
    expect(vm.error, isNull);
    expect(vm.profile!.email, myEmail);
    expect(vm.users, isNotEmpty);
    expect(vm.timings.length, 3);
    // ignore: avoid_print
    print(
        'Concurrente: ${vm.timings.map((t) => "${t.label}@${t.startMs}+${t.durationMs}").toList()} total=${vm.totalMs} ms');

    await vm.loadSequential();
    expect(vm.error, isNull);
    // ignore: avoid_print
    print(
        'Secuencial:  ${vm.timings.map((t) => "${t.label}@${t.startMs}+${t.durationMs}").toList()} total=${vm.totalMs} ms');

    // Con latencia simulada, Future.wait() debe ganar claramente
    expect(vm.concurrentMs!, lessThan(vm.sequentialMs!));
  });

  test('CRUD de usuarios', () async {
    final otherEmail = 'crud$stamp@test.com';

    // Crear
    final createVm = UserFormViewModel(userRepository, null);
    expect(await createVm.save('Crud', otherEmail, '123456'), isTrue,
        reason: createVm.error);

    // Listar
    final listVm = UserListViewModel(userRepository);
    await listVm.loadUsers();
    final created = listVm.users.firstWhere((u) => u.email == otherEmail);

    // Ver + editar (password vacia = conservar)
    final editVm = UserFormViewModel(userRepository, created.id);
    await editVm.loadUser();
    expect(editVm.user!.name, 'Crud');
    expect(await editVm.save('Crud Editado', otherEmail, ''), isTrue,
        reason: editVm.error);
    expect((await userRepository.getUser(created.id)).name, 'Crud Editado');

    // Email duplicado -> error del backend visible
    final dupVm = UserFormViewModel(userRepository, null);
    expect(await dupVm.save('Dup', otherEmail, '123456'), isFalse);
    expect(dupVm.error, contains('ya esta registrado'));

    // Eliminar
    expect(await listVm.deleteUser(created), isNull);
    expect(listVm.users.any((u) => u.id == created.id), isFalse);
  });

  test('upload multipart con progreso', () async {
    final vm = UploadViewModel(fileRepository);
    final progressValues = <double>[];
    vm.addListener(() => progressValues.add(vm.progress));

    // Simula el archivo elegido con file_picker (PNG de 1x1)
    vm.selectedFile = PickedFile(
      name: 'pixel.png',
      bytes: Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0,
        0,
        0,
        13,
        0x49,
        0x48,
        0x44,
        0x52,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0,
        0,
        0,
        13,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0xF8,
        0xCF,
        0xC0,
        0xF0,
        0x1F,
        0,
        0x05,
        0,
        0x01,
        0xFF,
        0x89,
        0x99,
        0x3D,
        0x1D,
        0,
        0,
        0,
        0,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82
      ]),
    );

    await vm.upload();
    expect(vm.error, isNull);
    expect(vm.uploadedFile!.originalName, 'pixel.png');
    expect(vm.uploadedFile!.contentType, 'image/png');
    expect(vm.progress, 1.0);

    // Galeria: el archivo aparece primero y su contenido se descarga igual
    final filesVm = FilesViewModel(fileRepository);
    await filesVm.loadFiles();
    final first = filesVm.files.first;
    expect(first.id, vm.uploadedFile!.id);
    // Usuario nuevo: solo ve su propio archivo
    expect(filesVm.totalCount, 1);
    filesVm.setFilter(FileFilter.images);
    expect(filesVm.files.every((f) => f.isImage), isTrue);

    final viewer = FileViewerViewModel(fileRepository, first);
    await viewer.load();
    expect(viewer.content, vm.selectedFile!.bytes);

    // Eliminar: desaparece de la lista
    expect(await viewer.delete(), isNull);
    await filesVm.loadFiles();
    expect(filesVm.totalCount, 0);
    expect(progressValues.where((p) => p > 0 && p <= 1), isNotEmpty);
  });

  test('token invalido -> 401 -> se borra el token', () async {
    await tokenStorage.saveToken('token.invalido.xxx');
    final vm = UserListViewModel(userRepository);
    await vm.loadUsers();
    expect(vm.error, isNotNull);
    expect(unauthorizedCalls, 1);
    expect(await tokenStorage.getToken(), isNull);
  });

  test('logout elimina el token', () async {
    await authRepository.login(myEmail, '123456');
    expect(await authRepository.isLoggedIn(), isTrue);
    await HomeViewModel(userRepository, fileRepository, authRepository)
        .logout();
    expect(await authRepository.isLoggedIn(), isFalse);
  });
}
