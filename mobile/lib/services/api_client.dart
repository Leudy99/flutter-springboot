import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'token_storage.dart';

/// Cliente HTTP compartido por todos los services.
///
/// Un interceptor agrega "Authorization: Bearer TOKEN" a cada peticion
/// y, si el backend responde 401, borra el token y avisa a la app.
class ApiClient {
  /// URL del backend.
  /// - Web: localhost
  /// - Emulador Android: 10.0.2.2 (es el localhost del PC)
  /// - Dispositivo fisico: flutter run --dart-define=API_URL=http://IP_DEL_PC:8081
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return kIsWeb ? 'http://localhost:8081' : 'http://10.0.2.2:8081';
  }

  final TokenStorage _tokenStorage;
  late final Dio dio;

  /// Se llama cuando el token es invalido o expiro (la app vuelve al login).
  VoidCallback? onUnauthorized;

  ApiClient(this._tokenStorage) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isAuthRequest = error.requestOptions.path.startsWith('/auth');
        if (error.response?.statusCode == 401 && !isAuthRequest) {
          await _tokenStorage.clear();
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }
}

/// Convierte cualquier error en un mensaje legible para mostrar en pantalla.
/// Usa el campo "message" que devuelve el GlobalExceptionHandler del backend.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['errors'] is Map) {
      return (data['errors'] as Map).values.join('\n');
    }
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.response == null) {
      return 'No se pudo conectar con el servidor (${ApiClient.baseUrl})';
    }
    return 'Error ${error.response?.statusCode}';
  }
  return error.toString();
}
