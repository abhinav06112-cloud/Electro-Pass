import 'package:flutter/material.dart';

import 'models.dart';
import 'paper.dart';

/// Builds the Material theme around the selected paper palette.
class AppTheme {
  AppTheme._();

  static const List<Palette> palettes = appPalettes;

  /// Readable foreground for a coloured chip or badge.
  static Color onColor(Color color) =>
      color.computeLuminance() > .48 ? Paper.ink : Paper.card;

  static Color card(BuildContext context) => context.pal.surface;

  static Color muted(BuildContext context) => context.pal.muted;

  static Border border(BuildContext context) =>
      Border.all(color: context.pal.line);

  static Color tintBg(ItemType type, Palette palette) =>
      type.tint.withValues(alpha: .10);

  static ThemeData build(Palette p) {
    const brightness = Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: Paper.clay,
      onSecondary: Colors.white,
      error: Paper.red,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      surfaceContainerHighest: p.surface2,
      outline: p.line,
      outlineVariant: p.line,
      primaryContainer: p.primary.withValues(alpha: .12),
      onPrimaryContainer: p.primary,
    );

    final base = ThemeData(brightness: brightness);

    OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      extensions: [PaletteExt(p)],
      textTheme: base.textTheme
          .copyWith(
            displayLarge: TextStyle(
              fontFamily: Paper.serif,
              fontSize: 40,
              height: 1.06,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
              color: p.ink,
            ),
            headlineLarge: TextStyle(
              fontFamily: Paper.serif,
              fontSize: 29,
              height: 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: -.7,
              color: p.ink,
            ),
            headlineMedium: TextStyle(
              fontFamily: Paper.serif,
              fontSize: 23,
              height: 1.18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
              color: p.ink,
            ),
            titleLarge: TextStyle(
              fontFamily: Paper.serif,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
            titleMedium: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
            bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: p.ink),
            bodyMedium: TextStyle(fontSize: 13.5, height: 1.45, color: p.muted),
            labelLarge: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          )
          .apply(bodyColor: p.ink, displayColor: p.ink),
      dividerColor: p.line,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surface2,
        circularTrackColor: p.surface2,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface2,
        selectedColor: p.primary.withValues(alpha: .12),
        side: BorderSide(color: p.line),
        labelStyle: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
        secondaryLabelStyle:
            TextStyle(color: p.primary, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.primary,
        titleTextStyle:
            TextStyle(color: p.ink, fontWeight: FontWeight.w700, fontSize: 15),
        subtitleTextStyle: TextStyle(color: p.muted, fontSize: 12.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.ink,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: Paper.serif,
          color: p.ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: fieldBorder(p.line),
        enabledBorder: fieldBorder(p.line),
        focusedBorder: fieldBorder(p.primary, 1.6),
        errorBorder: fieldBorder(Paper.red, 1.4),
        focusedErrorBorder: fieldBorder(Paper.red, 1.6),
        hintStyle: TextStyle(color: p.muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primary.withValues(alpha: .10),
        elevation: 0,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: s.contains(WidgetState.selected) ? p.ink : p.muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? p.primary : p.muted,
            )),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: p.line, width: 1.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.surface2,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
