/// Resultado de un algoritmo (ordenamiento o busqueda) dentro de la carrera.
class AlgorithmResult {
  final String algorithm;
  final String category; // SORT o SEARCH
  final DateTime startTime;
  final DateTime endTime;
  final double durationMilliseconds;
  final int durationNanoseconds;
  final int memoryBeforeBytes;
  final int memoryDuringBytes;
  final int memoryAfterBytes;
  final bool success;
  final bool timedOut; // supero el tiempo limite y se interrumpio
  final bool? found; // solo busquedas
  final int? index; // solo busquedas
  final String threadName;

  AlgorithmResult({
    required this.algorithm,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.durationMilliseconds,
    required this.durationNanoseconds,
    required this.memoryBeforeBytes,
    required this.memoryDuringBytes,
    required this.memoryAfterBytes,
    required this.success,
    required this.timedOut,
    required this.found,
    required this.index,
    required this.threadName,
  });

  bool get isSort => category == 'SORT';

  factory AlgorithmResult.fromJson(Map<String, dynamic> json) =>
      AlgorithmResult(
        algorithm: json['algorithm'] as String,
        category: json['category'] as String,
        startTime: DateTime.parse(json['startTime'] as String).toLocal(),
        endTime: DateTime.parse(json['endTime'] as String).toLocal(),
        durationMilliseconds: (json['durationMilliseconds'] as num).toDouble(),
        durationNanoseconds: (json['durationNanoseconds'] as num).toInt(),
        memoryBeforeBytes: (json['memoryBeforeBytes'] as num).toInt(),
        memoryDuringBytes: (json['memoryDuringBytes'] as num).toInt(),
        memoryAfterBytes: (json['memoryAfterBytes'] as num).toInt(),
        success: json['success'] as bool,
        timedOut: json['timedOut'] as bool? ?? false,
        found: json['found'] as bool?,
        index: (json['index'] as num?)?.toInt(),
        threadName: json['threadName'] as String? ?? '',
      );
}

/// Una fila de un ranking de velocidad.
class RankingEntry {
  final int position;
  final String algorithm;
  final String category;
  final double durationMilliseconds;
  final int durationNanoseconds;

  RankingEntry({
    required this.position,
    required this.algorithm,
    required this.category,
    required this.durationMilliseconds,
    required this.durationNanoseconds,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
        position: (json['position'] as num).toInt(),
        algorithm: json['algorithm'] as String,
        category: json['category'] as String,
        durationMilliseconds: (json['durationMilliseconds'] as num).toDouble(),
        durationNanoseconds: (json['durationNanoseconds'] as num).toInt(),
      );
}

/// Respuesta completa de POST /api/algorithm-race/run.
class AlgorithmRaceResult {
  final int arraySize;
  final int target;
  final int availableProcessors;
  final int timeLimitSeconds;
  final double totalRaceMilliseconds;
  final List<AlgorithmResult> results;
  final String? winner;
  final String? sortWinner;
  final String? searchWinner;
  final List<RankingEntry> ranking;
  final List<RankingEntry> sortRanking;
  final List<RankingEntry> searchRanking;

  AlgorithmRaceResult({
    required this.arraySize,
    required this.target,
    required this.availableProcessors,
    required this.timeLimitSeconds,
    required this.totalRaceMilliseconds,
    required this.results,
    required this.winner,
    required this.sortWinner,
    required this.searchWinner,
    required this.ranking,
    required this.sortRanking,
    required this.searchRanking,
  });

  List<AlgorithmResult> get sortResults =>
      results.where((r) => r.isSort).toList();
  List<AlgorithmResult> get searchResults =>
      results.where((r) => !r.isSort).toList();

  static List<RankingEntry> _ranking(dynamic list) => (list as List)
      .map((e) => RankingEntry.fromJson(e as Map<String, dynamic>))
      .toList();

  factory AlgorithmRaceResult.fromJson(Map<String, dynamic> json) =>
      AlgorithmRaceResult(
        arraySize: (json['arraySize'] as num).toInt(),
        target: (json['target'] as num).toInt(),
        availableProcessors: (json['availableProcessors'] as num).toInt(),
        timeLimitSeconds: (json['timeLimitSeconds'] as num).toInt(),
        totalRaceMilliseconds: (json['totalRaceMilliseconds'] as num).toDouble(),
        results: (json['results'] as List)
            .map((e) => AlgorithmResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        winner: json['winner'] as String?,
        sortWinner: json['sortWinner'] as String?,
        searchWinner: json['searchWinner'] as String?,
        ranking: _ranking(json['ranking']),
        sortRanking: _ranking(json['sortRanking']),
        searchRanking: _ranking(json['searchRanking']),
      );
}
