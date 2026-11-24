import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta de la app. Todos los colores salen de aqui.
class AppColors {
  static const ink = Color(0xFF12191F); // texto principal
  static const inkSoft = Color(0xFF5B6670); // texto secundario
  static const teal = Color(0xFF0B6B61); // unico acento de la app
  static const tealSoft = Color(0xFFE5F0EE);
  static const amber = Color(0xFF8A5A00); // solo avisos (p. ej. "Conectando")
  static const amberSoft = Color(0xFFF6EEDC);
  static const background = Color(0xFFF5F6F7);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE1E5E9);
  static const error = Color(0xFFB42318);
  static const errorSoft = Color(0xFFFDECEA);

  /// Un solo radio para toda la app (campos, botones, tarjetas, chips).
  static const radius = 10.0;
}

/// Tema visual de toda la app (tipografia, campos, botones, paneles).
class AppTheme {
  static const fontFamily = 'IBMPlexSans';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      secondary: AppColors.amber,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );
    final fieldRadius = BorderRadius.circular(AppColors.radius);

    const text = TextTheme(
      headlineMedium: TextStyle(
          fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.15),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, height: 1.4),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      textTheme:
          text.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      scaffoldBackgroundColor: AppColors.background,
      dividerTheme:
          const DividerThemeData(color: AppColors.border, thickness: 1),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.inkSoft),
        prefixIconColor: AppColors.inkSoft,
        border: OutlineInputBorder(borderRadius: fieldRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          disabledBackgroundColor: AppColors.border,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: fieldRadius),
          textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: fieldRadius),
          textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.teal),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.ink,
          selectedForegroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: fieldRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.ink,
        secondarySelectedColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(fontFamily: fontFamily),
        secondaryLabelStyle:
            const TextStyle(fontFamily: fontFamily, color: Colors.white),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: fieldRadius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 64,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.teal
                  : AppColors.inkSoft,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.teal
                  : AppColors.inkSoft,
            )),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.teal),
    );
  }
}
