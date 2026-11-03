import 'package:flutter/foundation.dart';

/// Backends disponibles.
enum Backend {
  /// API en tu PC (Docker): http://localhost:8081
  local,

  /// API en AWS: API Gateway + Lambda + Neon + S3
  cloud,
}

/// Configuracion del backend. Es el UNICO lugar donde estan las URLs.
class AppConfig {
  /// Cambia esta linea para elegir contra que backend trabaja la app.
  static const Backend backend = Backend.cloud;

  /// URL de API Gateway (output "api_url" de Terraform).
  static const String cloudUrl =
      'https://k3gjsmho82.execute-api.us-east-2.amazonaws.com';

  /// URL del backend local:
  /// - navegador: localhost
  /// - emulador Android: 10.0.2.2 (asi ve el emulador al localhost del PC)
  static String get localUrl =>
      kIsWeb ? 'http://localhost:8081' : 'http://10.0.2.2:8081';

  /// URL que usa la app. Se puede forzar al ejecutar:
  ///   flutter run --dart-define=API_URL=http://IP_DEL_PC:8081
  static String get apiUrl {
    const forced = String.fromEnvironment('API_URL');
    if (forced.isNotEmpty) return forced;
    return backend == Backend.cloud ? cloudUrl : localUrl;
  }
}
