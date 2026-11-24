import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import 'algorithm_info.dart';
import 'algorithm_race_view_model.dart';
import 'models/algorithm_result.dart';
import 'race_results.dart';
import 'widgets/ui_kit.dart';

/// Pantalla "Carrera de Algoritmos": configurar -> ejecutar -> ver quien gana.
class AlgorithmRacePage extends StatefulWidget {
  const AlgorithmRacePage({super.key});

  @override
  State<AlgorithmRacePage> createState() => _AlgorithmRacePageState();
}

class _AlgorithmRacePageState extends State<AlgorithmRacePage> {
  static const _presets = [1000, 5000, 10000, 50000, 100000];

  final _formKey = GlobalKey<FormState>();
  final _sizeController = TextEditingController(text: '10,000');
  final _targetController = TextEditingController(text: '4567');
  int _tab = 0;

  @override
  void dispose() {
    _sizeController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  int get _size => int.parse(_sizeController.text.replaceAll(',', ''));

  Future<void> _run(AlgorithmRaceViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _tab = 0);
    await vm.run(_size, int.parse(_targetController.text.trim()));
  }

  void _usePreset(int size) {
    _sizeController.text = thousands(size);
    setState(() {});
  }

  String? _validateSize(String? value) {
    final number = int.tryParse((value ?? '').replaceAll(',', ''));
    if (number == null || number < 1) return 'Escribe un número mayor que 0';
    if (number > 2147483647) return 'Número demasiado grande';
    return null;
  }

  String? _validateTarget(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe el número a buscar';
    final number = int.tryParse(text);
    if (number == null) return 'Debe ser un número entero';
    if (number < -2147483648 || number > 2147483647) {
      return 'Fuera del rango de un entero (32 bits)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlgorithmRaceViewModel>();
    final result = vm.result;

    return Scaffold(
      appBar: AppBar(title: const Text('Carrera de Algoritmos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _configCard(vm),
                if (vm.isRunning) ...[
                  const SizedBox(height: 16),
                  const _RunningCard(),
                ],
                if (vm.error != null) ...[
                  const SizedBox(height: 16),
                  UiAlert(
                    icon: Icons.error_outline,
                    title: 'No se pudo ejecutar la carrera',
                    message: vm.error!.split('\n').skip(1).join(' '),
                    destructive: true,
                  ),
                ],
                if (result != null && !vm.isRunning) ..._results(result),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ configurar

  Widget _configCard(AlgorithmRaceViewModel vm) {
    final sizeField = UiField(
      label: 'Tamaño del arreglo',
      child: TextFormField(
        controller: _sizeController,
        enabled: !vm.isRunning,
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsFormatter()],
        decoration: const InputDecoration(
          hintText: '10,000',
          suffixText: 'números',
        ),
        validator: _validateSize,
        textInputAction: TextInputAction.next,
      ),
    );
    final targetField = UiField(
      label: 'Número a buscar',
      child: TextFormField(
        controller: _targetController,
        enabled: !vm.isRunning,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))],
        decoration: const InputDecoration(hintText: '4567'),
        validator: _validateTarget,
        onFieldSubmitted: (_) => _run(vm),
      ),
    );
    final button = FilledButton.icon(
      onPressed: vm.isRunning ? null : () => _run(vm),
      icon: vm.isRunning
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.inkSoft))
          : const Icon(Icons.play_arrow_rounded, size: 20),
      label: Text(vm.isRunning ? 'Ejecutando' : 'Ejecutar carrera'),
    );

    return UiCard(
      title: 'Nueva carrera',
      description: 'Los 5 algoritmos reciben los mismos datos y corren a la vez.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, c) {
              if (c.maxWidth >= 640) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sizeField),
                    const SizedBox(width: 12),
                    Expanded(child: targetField),
                    const SizedBox(width: 12),
                    // 24 px: alto de la etiqueta, para alinear con los campos
                    Padding(
                      padding: const EdgeInsets.only(top: 25),
                      child: SizedBox(width: 180, child: button),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sizeField,
                  const SizedBox(height: 14),
                  targetField,
                  const SizedBox(height: 16),
                  button,
                ],
              );
            }),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Probar con', style: uiMuted),
                for (final size in _presets)
                  OutlinedButton(
                    onPressed: vm.isRunning ? null : () => _usePreset(size),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    child: Text(thousands(size)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- resultados

  List<Widget> _results(AlgorithmRaceResult r) {
    return [
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          UiBadge('${thousands(r.arraySize)} números',
              kind: BadgeKind.outline, icon: Icons.data_array),
          UiBadge('Buscando ${r.target}',
              kind: BadgeKind.outline, icon: Icons.search),
          UiBadge('${r.availableProcessors} núcleos',
              kind: BadgeKind.outline, icon: Icons.memory),
          UiBadge(
              'Carrera: ${fmtDuration((r.totalRaceMilliseconds * 1e6).round())}',
              kind: BadgeKind.outline,
              icon: Icons.timer_outlined),
        ],
      ),
      const SizedBox(height: 14),
      WinnerCards(r),
      const SizedBox(height: 16),
      UiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: UiTabs(
                labels: const ['Ranking', 'En paralelo', 'Detalle'],
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 20),
            switch (_tab) {
              0 => RankingTab(r),
              1 => ParallelTab(r),
              _ => DetailTab(r),
            },
          ],
        ),
      ),
    ];
  }
}

/// Mientras corre la carrera: una fila por algoritmo con barra "cargando".
class _RunningCard extends StatelessWidget {
  const _RunningCard();

  @override
  Widget build(BuildContext context) {
    return UiCard(
      title: 'Ejecutando carrera...',
      description: 'Cada algoritmo corre ahora mismo en su propio hilo.',
      child: Column(
        children: [
          for (final name in competitorNames)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ]),
                  const SizedBox(height: 8),
                  const UiSkeleton(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
