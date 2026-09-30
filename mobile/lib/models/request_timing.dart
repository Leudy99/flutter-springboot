/// Cuando empezo y cuanto duro una peticion HTTP (para la demo de concurrencia).
/// [startMs] se mide desde el inicio de la carga completa.
class RequestTiming {
  final String label;
  final int startMs;
  final int durationMs;

  const RequestTiming(this.label, this.startMs, this.durationMs);

  int get endMs => startMs + durationMs;
}
