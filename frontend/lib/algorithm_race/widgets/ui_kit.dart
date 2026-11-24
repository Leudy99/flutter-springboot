import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// Componentes pequenos inspirados en shadcn/ui (Card, Badge, Tabs, Progress,
/// Skeleton, Alert, Label). Mismos colores y radio que el resto de la app.

const uiMuted = TextStyle(color: AppColors.inkSoft, fontSize: 13);
const uiMutedBg = Color(0xFFEEF0F2);

// ----------------------------------------------------------------- Card

/// Tarjeta con titulo y descripcion opcionales (CardHeader + CardContent).
class UiCard extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget? action;
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  const UiCard({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.action,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(children: [
              Expanded(
                child: Text(title!,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2)),
              ),
              ?action,
            ]),
            if (description != null) ...[
              const SizedBox(height: 2),
              Text(description!, style: uiMuted),
            ],
            const SizedBox(height: 18),
          ],
          child,
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Badge

enum BadgeKind { neutral, outline, accent, destructive, inverted }

class UiBadge extends StatelessWidget {
  final String text;
  final BadgeKind kind;
  final IconData? icon;

  const UiBadge(this.text,
      {super.key, this.kind = BadgeKind.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      BadgeKind.neutral => (uiMutedBg, AppColors.ink, Colors.transparent),
      BadgeKind.outline => (Colors.transparent, AppColors.ink, AppColors.border),
      BadgeKind.accent => (AppColors.tealSoft, AppColors.teal, Colors.transparent),
      BadgeKind.destructive =>
        (AppColors.errorSoft, AppColors.error, Colors.transparent),
      BadgeKind.inverted =>
        (const Color(0x26FFFFFF), Colors.white, Colors.transparent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(text,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ Tabs

/// Pestanas en forma de pildora gris con la activa en blanco (shadcn Tabs).
class UiTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const UiTabs(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: uiMutedBg,
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: i == selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppColors.radius - 3),
                  border: Border.all(
                      color: i == selected
                          ? AppColors.border
                          : Colors.transparent),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: i == selected
                            ? AppColors.ink
                            : AppColors.inkSoft)),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Progress

class UiProgress extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;

  const UiProgress(this.value,
      {super.key, this.color = AppColors.teal, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Stack(children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: uiMutedBg,
            borderRadius: BorderRadius.circular(height),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          height: height,
          width: c.maxWidth * value.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height),
          ),
        ),
      ]);
    });
  }
}

// -------------------------------------------------------------- Skeleton

/// Barra gris que pulsa mientras se espera (carga con la forma del contenido).
class UiSkeleton extends StatefulWidget {
  final double height;
  final double? width;

  const UiSkeleton({super.key, this.height = 8, this.width});

  @override
  State<UiSkeleton> createState() => _UiSkeletonState();
}

class _UiSkeletonState extends State<UiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(uiMutedBg, const Color(0xFFDDE1E5),
              reduce ? 0 : _controller.value),
          borderRadius: BorderRadius.circular(widget.height),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Alert

class UiAlert extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool destructive;

  const UiAlert(
      {super.key,
      required this.icon,
      required this.title,
      this.message,
      this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.ink;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
            color: destructive
                ? AppColors.error.withValues(alpha: .4)
                : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(message!,
                        style: TextStyle(
                            color: destructive ? color : AppColors.inkSoft,
                            fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Label

/// Etiqueta sobre el campo (nunca dentro como placeholder).
class UiField extends StatelessWidget {
  final String label;
  final Widget child;

  const UiField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Icono "i" que explica algo al pasar el cursor o tocarlo (menos texto fijo).
class InfoTip extends StatelessWidget {
  final String message;

  const InfoTip(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(10),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.info_outline, size: 16, color: AppColors.inkSoft),
      ),
    );
  }
}

// ------------------------------------------------------ Formato de numeros

/// Escribe 50000 como 50,000 mientras se teclea.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
