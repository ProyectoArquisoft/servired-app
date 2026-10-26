import 'package:flutter/material.dart';

/// Tema de la app. Prioriza contraste y áreas táctiles grandes (≥ 48 dp)
/// para usuarios con bajo nivel digital.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF0B5CAD);

  /// Alto mínimo de los botones principales.
  static const double primaryButtonHeight = 64;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      contrastLevel: 0.5,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const buttonTextStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: buttonShape,
          textStyle: buttonTextStyle,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: buttonShape,
          textStyle: buttonTextStyle,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
