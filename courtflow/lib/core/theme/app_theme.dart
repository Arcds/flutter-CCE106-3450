import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color evergreen = Color(0xFF1B5E4B);
  static const Color deepEvergreen = Color(0xFF0E3A2E);
  static const Color lime = Color(0xFFCBEA6B);
  static const Color sand = Color(0xFFF5F4EE);
  static const Color ink = Color(0xFF18211D);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: evergreen,
      brightness: Brightness.light,
    ).copyWith(
      primary: evergreen,
      onPrimary: Colors.white,
      secondary: const Color(0xFF5E8C55),
      surface: Colors.white,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: sand,
      visualDensity: VisualDensity.standard,
    );
  }

  static BoxDecoration cardDecoration({Color? color, double radius = 20}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
