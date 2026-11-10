import 'package:flutter/material.dart';

/// Colour tokens from the v1 wireframes. Widgets use [ThemeData], never
/// these directly, except when building the theme.
abstract final class OrbitColors {
  /// App background.
  static const ground = Color(0xFF15132B);

  /// Cards, inputs and sheets.
  static const surface = Color(0xFF221F3F);

  /// Hairlines and inactive borders.
  static const outline = Color(0xFF3A3566);

  /// Primary text.
  static const text = Color(0xFFF4F2FF);

  /// Secondary text; 6.7:1 on [surface].
  static const textMuted = Color(0xFFA9A4D1);

  /// Brand accent for primary actions.
  static const coral = Color(0xFFFF7A66);

  /// Online indicator.
  static const online = Color(0xFF4ADE80);
}

/// Builds the single dark theme used by Orbit v1.
ThemeData buildOrbitTheme() {
  const scheme = ColorScheme.dark(
    primary: OrbitColors.coral,
    onPrimary: OrbitColors.ground,
    surface: OrbitColors.ground,
    onSurface: OrbitColors.text,
    surfaceContainer: OrbitColors.surface,
    onSurfaceVariant: OrbitColors.textMuted,
    outline: OrbitColors.outline,
  );
  const minTapSize = Size(double.infinity, 52);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minTapSize,
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minTapSize,
        shape: buttonShape,
        foregroundColor: scheme.onSurface,
        backgroundColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.surfaceContainer,
    ),
  );
}
