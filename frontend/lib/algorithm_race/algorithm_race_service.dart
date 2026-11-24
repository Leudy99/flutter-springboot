import 'package:dio/dio.dart';

import '../services/api_client.dart';
import 'models/algorithm_result.dart';

/// Peticion HTTP de la Carrera de Algoritmos: POST /api/algorithm-race/run (JWT).
class AlgorithmRaceService {
  final ApiClient _api;

  AlgorithmRaceService(this._api);

  Future<AlgorithmRaceResult> run(int arraySize, int target) async {
    final response = await _api.dio.post(
      '/api/algorithm-race/run',
      data: {'arraySize': arraySize, 'target': target},
      // Bubble Sort con 50,000 elementos puede tardar bastante: mas margen
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return AlgorithmRaceResult.fromJson(response.data as Map<String, dynamic>);
  }
}
