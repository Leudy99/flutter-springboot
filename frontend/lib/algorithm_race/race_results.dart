import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'algorithm_info.dart';
import 'models/algorithm_result.dart';
import 'widgets/ui_kit.dart';

/// Numeros con ancho fijo para que las columnas queden alineadas.
const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

// ======================================================================
// Tarjetas de ganadores
// ======================================================================

class WinnerCards extends StatelessWidget {
  final AlgorithmRaceResult race;

  const WinnerCards(this.race, {super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _WinnerCard(
        label: 'Ganador general',
        name: race.winner,
        group: race.results,
        winnerName: race.winner,
        limit: race.timeLimitSeconds,
        primary: true,
      ),
      _WinnerCard(
        label: 'Ordenamiento',
        name: race.sortWinner,
        group: race.sortResults,
        winnerName: race.sortWinner,
        limit: race.timeLimitSeconds,
      ),
      _WinnerCard(
        label: 'Búsqueda',
        name: race.searchWinner,
        group: race.searchResults,
        winnerName: race.searchWinner,
        limit: race.timeLimitSeconds,
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 640) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      }
      return Column(children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          cards[i],
        ],
      ]);
    });
  }
}

class _WinnerCard extends StatelessWidget {
  final String label;
  final String? name;
  final List<AlgorithmResult> group;
  final String? winnerName;
  final int limit;
  final bool primary;

  const _WinnerCard({
    required this.label,
    required this.name,
    required this.group,
    required this.winnerName,
    required this.limit,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final winner = group.where((r) => r.algorithm == winnerName).firstOrNull;
    final slowest = group.isEmpty
        ? null
        : group.reduce((a, b) =>
            a.durationNanoseconds >= b.durationNanoseconds ? a : b);

    String? vs;
    if (winner != null &&
        slowest != null &&
        slowest.algorithm != winner.algorithm &&
        winner.durationNanoseconds > 0) {
      final factor = slowest.durationNanoseconds / winner.durationNanoseconds;
      vs = '${slowest.timedOut ? '+' : ''}${fmtTimes(factor)} más rápido '
          'que ${slowest.algorithm}';
    }

    final fg = primary ? Colors.white : AppColors.ink;
    final sub = primary ? const Color(0xFFCFE4E1) : AppColors.inkSoft;

    return UiCard(
      color: primary ? AppColors.teal : AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: sub, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text(name ?? 'Sin ganador',
              style: TextStyle(
                  color: fg,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          const SizedBox(height: 2),
          Text(winner == null ? '' : fmtDuration(winner.durationNanoseconds),
              style: _tabular.copyWith(color: fg, fontSize: 15)),
          if (primary && winner != null) ...[
            const SizedBox(height: 10),
            const UiBadge('El más rápido de los 5', kind: BadgeKind.inverted),
          ] else if (vs != null) ...[
            const SizedBox(height: 10),
            UiBadge(vs, kind: BadgeKind.accent),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// Pestana 1: Ranking
// ======================================================================

class RankingTab extends StatefulWidget {
  final AlgorithmRaceResult race;

  const RankingTab(this.race, {super.key});

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  int _filter = 0; // 0 todos, 1 ordenamiento, 2 busqueda

  @override
  Widget build(BuildContext context) {
    final race = widget.race;
    final entries = switch (_filter) {
      1 => race.sortRanking,
      2 => race.searchRanking,
      _ => race.ranking,
    };
    final timedOut = race.results.where((r) {
      if (!r.timedOut) return false;
      return _filter == 0 || (_filter == 1) == r.isSort;
    }).toList();

    // La barra mide el tiempo respecto al mas lento de la lista mostrada
    final maxNs = entries.map((e) => e.durationNanoseconds).fold(1, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          PopupMenuButton<int>(
            initialValue: _filter,
            onSelected: (i) => setState(() => _filter = i),
            position: PopupMenuPosition.under,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Todos los algoritmos')),
              PopupMenuItem(value: 1, child: Text('Solo ordenamiento')),
              PopupMenuItem(value: 2, child: Text('Solo búsqueda')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    const [
                      'Todos los algoritmos',
                      'Solo ordenamiento',
                      'Solo búsqueda'
                    ][_filter],
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.unfold_more, size: 16, color: AppColors.inkSoft),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          const InfoTip('Menos tiempo = mejor posición. Barra corta = algoritmo '
              'rápido. Los tiempos están en milisegundos (ms); los '
              'nanosegundos exactos están en la pestaña Detalle.'),
        ]),
        const SizedBox(height: 18),
        for (final e in entries)
          _row(e, (e.durationNanoseconds / maxNs).clamp(.012, 1.0)),
        for (final r in timedOut) _timedOutRow(r, race.timeLimitSeconds),
      ],
    );
  }

  Widget _row(RankingEntry e, double fraction) {
    final first = e.position == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: 26,
              child: Text('${e.position}',
                  style: _tabular.copyWith(
                      fontWeight: FontWeight.w700,
                      color: first ? AppColors.teal : AppColors.inkSoft)),
            ),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(e.algorithm,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Text(fmtDuration(e.durationNanoseconds),
                style: _tabular.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: UiProgress(fraction, color: AppColors.teal),
          ),
        ],
      ),
    );
  }

  Widget _timedOutRow(AlgorithmResult r, int limit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        const SizedBox(
            width: 26, child: Text('-', style: TextStyle(color: AppColors.inkSoft))),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(r.algorithm,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        UiBadge('No terminó en $limit s', kind: BadgeKind.destructive),
      ]),
    );
  }
}

// ======================================================================
// Pestana 2: En paralelo
// ======================================================================

class ParallelTab extends StatelessWidget {
  final AlgorithmRaceResult race;

  const ParallelTab(this.race, {super.key});

  @override
  Widget build(BuildContext context) {
    final results = race.results;
    final maxNs = results.map((r) => r.durationNanoseconds).reduce(math.max);

    // Diferencia real entre el primer y el ultimo hilo en arrancar
    final starts = results.map((r) => r.startTime).toList()..sort();
    final jitter =
        '${(starts.last.difference(starts.first).inMicroseconds / 1000).toStringAsFixed(2)} ms';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiAlert(
          icon: Icons.account_tree_outlined,
          title: 'Los 5 hilos arrancan juntos',
          message: 'Cada barra empieza en el inicio de su hilo y crece hasta '
              'que el algoritmo termina. Diferencia de arranque entre hilos: $jitter.',
        ),
        const SizedBox(height: 20),
        for (final r in results)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(r.algorithm,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                  Text(
                      r.timedOut
                          ? 'Interrumpido a los ${race.timeLimitSeconds} s'
                          : fmtDuration(r.durationNanoseconds),
                      style: _tabular.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: r.timedOut ? AppColors.error : AppColors.ink)),
                ]),
                const SizedBox(height: 6),
                UiProgress(
                  (r.durationNanoseconds / maxNs).clamp(.012, 1.0),
                  color: r.timedOut ? AppColors.error : AppColors.teal,
                ),
              ],
            ),
          ),
        Row(children: [
          const Text('Inicio', style: uiMuted),
          const Spacer(),
          Text('Fin del más lento: ${fmtDuration(maxNs)}', style: uiMuted),
        ]),
      ],
    );
  }
}

// ======================================================================
// Pestana 3: Detalle
// ======================================================================

class DetailTab extends StatelessWidget {
  final AlgorithmRaceResult race;

  const DetailTab(this.race, {super.key});

  @override
  Widget build(BuildContext context) {
    final rows = [...race.sortResults, ...race.searchResults];
    final peak =
        rows.map((r) => r.memoryDuringBytes).reduce((a, b) => a > b ? a : b);

    const head = TextStyle(
        color: AppColors.inkSoft, fontSize: 12, fontWeight: FontWeight.w600);
    const body = TextStyle(fontSize: 12.5);

    Widget cell(String text, {TextStyle? style, bool left = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Text(text,
              textAlign: left ? TextAlign.left : TextAlign.right,
              style: (style ?? body).merge(_tabular)),
        );

    final table = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: const TableBorder(
          horizontalInside: BorderSide(color: AppColors.border)),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF7F8F9)),
          children: [
            cell('Algoritmo', style: head, left: true),
            cell('Inicio', style: head),
            cell('Fin', style: head),
            cell('ms', style: head),
            cell('ns', style: head),
            cell('Mem. antes', style: head),
            cell('Mem. durante', style: head),
            cell('Mem. final', style: head),
          ],
        ),
        for (final r in rows)
          TableRow(children: [
            cell(r.algorithm,
                style: body.copyWith(fontWeight: FontWeight.w600), left: true),
            if (r.timedOut) ...[
              for (var i = 0; i < 7; i++)
                cell(i == 2 ? 'Tiempo límite' : '-',
                    style: body.copyWith(color: AppColors.error)),
            ] else ...[
              cell(fmtClock(r.startTime)),
              cell(fmtClock(r.endTime)),
              cell(r.durationMilliseconds.toStringAsFixed(3)),
              cell(thousands(r.durationNanoseconds)),
              cell(fmtBytes(r.memoryBeforeBytes)),
              cell(fmtBytes(r.memoryDuringBytes),
                  style: body.copyWith(
                      fontWeight: r.memoryDuringBytes == peak
                          ? FontWeight.w700
                          : FontWeight.w400)),
              cell(fmtBytes(r.memoryAfterBytes)),
            ],
          ]),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Respuesta de las busquedas: el numero estaba o no en el arreglo
        Text('Resultado de las búsquedas',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        for (final r in race.searchResults)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(r.algorithm,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (r.timedOut)
                  const UiBadge('No terminó', kind: BadgeKind.destructive)
                else if (r.found == true)
                  UiBadge(
                      'Encontró el ${race.target} en la posición ${thousands(r.index ?? 0)}',
                      kind: BadgeKind.accent,
                      icon: Icons.check)
                else
                  UiBadge('El ${race.target} no está en el arreglo',
                      icon: Icons.close),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('Tiempos y memoria por algoritmo',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(builder: (context, c) {
            // En pantallas anchas la tabla se ajusta al ancho (sin cortarse);
            // en moviles se desliza horizontalmente.
            if (c.maxWidth >= 700) {
              return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: table);
            }
            return SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: table);
          }),
        ),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(
            child: Text('Memoria aproximada. En negrita, el mayor pico.',
                style: uiMuted),
          ),
          InfoTip('La JVM comparte la memoria entre los 5 hilos y el Garbage '
              'Collector puede actuar en cualquier momento, por eso las '
              'cifras de memoria son aproximadas.'),
        ]),
      ],
    );
  }
}
