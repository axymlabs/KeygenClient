import 'package:flutter/material.dart';

/// Visual language: near-black canvas, hairline borders, flat panels,
/// monospace for data, a single cool accent. Light mode follows Apple's greys.
class AppTheme {
  static const _monoFamily = 'Menlo';
  static const _monoFallback = [
    'SF Mono',
    'Roboto Mono',
    'Consolas',
    'monospace'
  ];

  static TextStyle mono(BuildContext context,
          {double size = 13, FontWeight? weight, Color? color}) =>
      TextStyle(
        fontFamily: _monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ColorScheme _scheme(Brightness b) {
    if (b == Brightness.dark) {
      return const ColorScheme.dark(
        primary: Color(0xFF7EF0CF),
        onPrimary: Color(0xFF082820),
        primaryContainer: Color(0xFF143C35),
        onPrimaryContainer: Color(0xFFB1F8E3),
        secondary: Color(0xFF9AA3AF),
        secondaryContainer: Color(0xFF1B1F24),
        onSecondaryContainer: Color(0xFFE6E8EB),
        surface: Color(0xFF0B141E),
        onSurface: Color(0xFFEAF1F7),
        onSurfaceVariant: Color(0xFF8CA0B5),
        outline: Color(0xFF3A5069),
        outlineVariant: Color(0xFF1C2E42),
        surfaceContainerLowest: Color(0xFF070E15),
        surfaceContainerLow: Color(0xFF101C29),
        surfaceContainer: Color(0xFF132133),
        surfaceContainerHigh: Color(0xFF172A3E),
        surfaceContainerHighest: Color(0xFF1D3248),
        error: Color(0xFFFF5C5C),
        errorContainer: Color(0xFF3A1416),
        onErrorContainer: Color(0xFFFFB4B4),
      );
    }
    return const ColorScheme.light(
      primary: Color(0xFF006B55),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD0F5E8),
      onPrimaryContainer: Color(0xFF00382B),
      secondary: Color(0xFF6B7280),
      secondaryContainer: Color(0xFFEDEDF0),
      onSecondaryContainer: Color(0xFF1D1D1F),
      surface: Color(0xFFF3F7F6),
      onSurface: Color(0xFF1D1D1F),
      onSurfaceVariant: Color(0xFF6E6E73),
      outline: Color(0xFFB8B8BF),
      outlineVariant: Color(0xFFE2E2E7),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Color(0xFFFFFFFF),
      surfaceContainerHigh: Color(0xFFEDEDF0),
      surfaceContainerHighest: Color(0xFFE5E5EA),
      error: Color(0xFFD92D20),
      errorContainer: Color(0xFFFDE8E6),
      onErrorContainer: Color(0xFF7A1410),
    );
  }

  static ThemeData build(Brightness b, {String? fontFamily}) {
    final cs = _scheme(b);
    final base = ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        brightness: b,
        fontFamily: fontFamily);
    final tt = base.textTheme
        .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    TextStyle s(TextStyle? t, double size, FontWeight w, [double ls = 0]) =>
        (t ??
                TextStyle(
                  fontFamily: fontFamily,
                ))
            .copyWith(
                fontSize: size, fontWeight: w, letterSpacing: ls, height: 1.2);

    final textTheme = tt.copyWith(
      headlineMedium: s(tt.headlineMedium, 34, FontWeight.w700, -1),
      headlineSmall: s(tt.headlineSmall, 26, FontWeight.w700, -0.6),
      titleLarge: s(tt.titleLarge, 17, FontWeight.w600, -0.2),
      titleMedium: s(tt.titleMedium, 16, FontWeight.w600, -0.2),
      titleSmall: s(tt.titleSmall, 14, FontWeight.w600, -0.1),
      bodyLarge:
          s(tt.bodyLarge, 16, FontWeight.w400, -0.2).copyWith(height: 1.35),
      bodyMedium:
          s(tt.bodyMedium, 14, FontWeight.w400, -0.1).copyWith(height: 1.35),
      bodySmall: s(tt.bodySmall, 12, FontWeight.w400, 0),
      labelMedium: s(tt.labelMedium, 12, FontWeight.w500, 0.1),
    );

    final hairline = BorderSide(color: cs.outlineVariant, width: 1);
    final radius = BorderRadius.circular(12);

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme:
          DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: hairline),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        subtitleTextStyle:
            textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: cs.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: cs.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: cs.error, width: 1.5)),
        labelStyle:
            TextStyle(fontFamily: fontFamily, color: cs.onSurfaceVariant),
        floatingLabelStyle:
            TextStyle(fontFamily: fontFamily, color: cs.primary),
        helperStyle: TextStyle(
            fontFamily: fontFamily, color: cs.onSurfaceVariant, fontSize: 12),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerLow,
        selectedColor: cs.onSurface,
        side: hairline,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
            fontFamily: fontFamily,
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 13),
        secondaryLabelStyle: TextStyle(
            fontFamily: fontFamily,
            color: cs.surface,
            fontWeight: FontWeight.w600,
            fontSize: 13),
        iconTheme: IconThemeData(color: cs.onSurfaceVariant, size: 18),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(hairline),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: radius)),
          textStyle: WidgetStatePropertyAll(TextStyle(
              fontFamily: fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? cs.onSurface
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? cs.surface
                  : cs.onSurfaceVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: s.contains(WidgetState.selected)
                  ? cs.onSurface
                  : cs.onSurfaceVariant,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected)
                  ? cs.primary
                  : cs.onSurfaceVariant,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.surfaceContainerHigh,
        selectedIconTheme: IconThemeData(color: cs.primary),
        unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
            fontFamily: fontFamily,
            color: cs.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(
            fontFamily: fontFamily, color: cs.onSurfaceVariant, fontSize: 11),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.onSurface,
        contentTextStyle: TextStyle(
            fontFamily: fontFamily,
            color: cs.surface,
            fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? cs.primary
                : cs.surfaceContainerHighest),
      ),
    );
  }
}
