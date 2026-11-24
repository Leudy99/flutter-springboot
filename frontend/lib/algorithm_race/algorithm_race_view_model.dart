import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import 'algorithm_race_service.dart';
import 'models/algorithm_result.dart';

/// Estado de la pantalla "Carrera de Algoritmos".
class AlgorithmRaceViewModel extends ChangeNotifier {
  final AlgorithmRaceService _service;

  AlgorithmRaceViewModel(this._service);

  bool isRunning = false;
  AlgorithmRaceResult? result;
  String? error;

  /// Ejecuta la carrera. Con una carrera en curso ignora nuevas llamadas
  /// (evita ejecuciones duplicadas).
  Future<void> run(int arraySize, int target) async {
    if (isRunning) return;
    isRunning = true;
    error = null;
    result = null;
    notifyListeners();
    try {
      result = await _service.run(arraySize, target);
    } catch (e) {
      error = 'No se pudo ejecutar la carrera.\n${apiErrorMessage(e)}';
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }
}
