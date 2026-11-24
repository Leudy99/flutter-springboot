/// Orden en que se muestran los competidores mientras corre la carrera.
const competitorNames = [
  'Bubble Sort',
  'Insertion Sort',
  'Quick Sort',
  'Sequential Search',
  'Binary Search',
];

// ------------------------------------------------------------- formatos

/// Nanosegundos -> milisegundos (la unidad en que mide la carrera):
/// 0.005 ms, 59.46 ms, 2,955.7 ms. Los ns exactos estan en la pestana Detalle.
String fmtDuration(int ns) {
  final ms = ns / 1000000.0;
  final decimals = ms < 1 ? 3 : (ms < 100 ? 2 : 1);
  final parts = ms.toStringAsFixed(decimals).split('.');
  return '${thousands(int.parse(parts[0]))}.${parts[1]} ms';
}

/// Bytes -> KB / MB con 2 decimales.
String fmtBytes(int bytes) {
  final abs = bytes.abs();
  if (abs < 1024) return '$bytes B';
  if (abs < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

/// Igual que fmtBytes pero con signo (+/-) para mostrar cambios.
String fmtDelta(int bytes) => bytes > 0 ? '+${fmtBytes(bytes)}' : fmtBytes(bytes);

/// 10000 -> 10,000
String thousands(int n) {
  final s = n.abs().toString();
  final buffer = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Hora en 12 horas con milisegundos y AM/PM: 06:45:10.125 PM
String fmtClock(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${two(hour12)}:${two(t.minute)}:${two(t.second)}.'
      '${t.millisecond.toString().padLeft(3, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "85×" / "3.2×"
String fmtTimes(double factor) =>
    factor >= 10 ? '${factor.round()}×' : '${factor.toStringAsFixed(1)}×';
