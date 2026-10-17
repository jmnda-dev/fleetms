import 'package:flutter/material.dart';

/// The FleetMS color tokens, kept in sync with the web app's Flowbite v4 theme
/// (`assets/css/app.css`). The web's default "midnight" theme is a deep-navy
/// brand accent over cool-slate neutrals; dark mode swaps the accent to a
/// lighter "sea blue" because the navy is unreadable on a dark ground.
///
/// Use these through the [Theme] (`Theme.of(context).colorScheme.…`) rather than
/// hard-coding hexes in widgets, so light/dark stays consistent everywhere.
class FleetmsColors {
  FleetmsColors._();

  // --- Brand ramp (navy) → `--color-primary-*` ---
  static const primary50 = Color(0xFFECF0FB);
  static const primary100 = Color(0xFFD3DDF6);
  static const primary200 = Color(0xFFA8BBEC);
  static const primary300 = Color(0xFF7793DE);
  static const primary400 = Color(0xFF4D6BCB);
  static const primary500 = Color(0xFF2E4BB0);
  static const primary600 = Color(0xFF213A8E);
  static const primary700 = Color(0xFF001A72);
  static const primary800 = Color(0xFF021556);
  static const primary900 = Color(0xFF04103B);
  static const primary950 = Color(0xFF060A24);

  // --- Sea-blue accent (dark-mode brand) → `--color-seablue-*` ---
  static const seablue20 = Color(0xFFE1F3FA);
  static const seablue40 = Color(0xFFB5E1F1);
  static const seablue60 = Color(0xFF87CCE8);
  static const seablue80 = Color(0xFF5BB9E0);
  static const seablue100 = Color(0xFF38ACDD);

  // --- Neutrals = cool slate → `--color-gray-*` ---
  static const gray50 = Color(0xFFF8FAFC);
  static const gray100 = Color(0xFFF1F5F9);
  static const gray200 = Color(0xFFE2E8F0);
  static const gray300 = Color(0xFFCBD5E1);
  static const gray400 = Color(0xFF94A3B8);
  static const gray500 = Color(0xFF64748B);
  static const gray600 = Color(0xFF475569);
  static const gray700 = Color(0xFF334155);
  static const gray800 = Color(0xFF1E293B);
  static const gray900 = Color(0xFF0F172A);
  static const gray950 = Color(0xFF020617);

  // --- Status ramps (danger→red, warning→amber, success→emerald) ---
  static const red50 = Color(0xFFFEF2F2);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);

  static const amber50 = Color(0xFFFFFBEB);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);

  static const emerald50 = Color(0xFFECFDF5);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
}

/// Light / dark [ThemeData] built from [FleetmsColors]. `--radius-base` (0.5rem)
/// becomes our 8px corner radius on cards, inputs and buttons, matching the
/// web's `rounded-base`.
class FleetmsTheme {
  FleetmsTheme._();

  static const double radius = 8;

  static ThemeData get light =>
      _build(_lightScheme, scaffold: FleetmsColors.gray50);
  static ThemeData get dark =>
      _build(_darkScheme, scaffold: FleetmsColors.gray900);

  // Brand navy on white; slate neutrals; page = gray-50, cards = white.
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: FleetmsColors.primary700,
    onPrimary: Colors.white,
    primaryContainer: FleetmsColors.primary100,
    onPrimaryContainer: FleetmsColors.primary900,
    secondary: FleetmsColors.primary600,
    onSecondary: Colors.white,
    secondaryContainer: FleetmsColors.primary50,
    onSecondaryContainer: FleetmsColors.primary900,
    tertiary: FleetmsColors.seablue100,
    onTertiary: Colors.white,
    surface: Colors.white,
    onSurface: FleetmsColors.gray900,
    surfaceContainerHighest: FleetmsColors.gray100,
    onSurfaceVariant: FleetmsColors.gray600,
    outline: FleetmsColors.gray300,
    outlineVariant: FleetmsColors.gray200,
    error: FleetmsColors.red600,
    onError: Colors.white,
    errorContainer: FleetmsColors.red50,
    onErrorContainer: FleetmsColors.red700,
  );

  // Sea-blue accent (with dark text) on near-black slate surfaces.
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: FleetmsColors.seablue60,
    onPrimary: FleetmsColors.primary900,
    primaryContainer: FleetmsColors.primary800,
    onPrimaryContainer: FleetmsColors.seablue40,
    secondary: FleetmsColors.seablue80,
    onSecondary: FleetmsColors.primary900,
    secondaryContainer: FleetmsColors.primary900,
    onSecondaryContainer: FleetmsColors.seablue40,
    tertiary: FleetmsColors.seablue100,
    onTertiary: FleetmsColors.primary900,
    surface: FleetmsColors.gray800,
    onSurface: Colors.white,
    surfaceContainerHighest: FleetmsColors.gray700,
    onSurfaceVariant: FleetmsColors.gray400,
    outline: FleetmsColors.gray700,
    outlineVariant: FleetmsColors.gray700,
    error: FleetmsColors.red500,
    onError: FleetmsColors.primary900,
    errorContainer: FleetmsColors.red700,
    onErrorContainer: FleetmsColors.red50,
  );

  static ThemeData _build(ColorScheme scheme, {required Color scaffold}) {
    final borderRadius = BorderRadius.circular(radius);
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      // The web uses Inter; bundle it under pubspec `fonts:` and set
      // `fontFamily: 'Inter'` here to match exactly. Left as the platform
      // default for now to avoid shipping the font binary in the scaffold.
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 2,
        shadowColor: isDark ? Colors.transparent : const Color(0x33000000), // subtle shadow
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: isDark ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? FleetmsColors.gray900 : FleetmsColors.gray50,
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
