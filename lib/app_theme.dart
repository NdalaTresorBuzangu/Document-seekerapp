import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand accents (red header strip, blue primary family) for Document Seeker.
abstract final class TshijukaBranding {
  static const Color navRedLight = Color(0xFFDC3545);
  static const Color navRedDark = Color(0xFFC82333);
  static const Color heroBlueTop = Color(0xFF2563EB);
  static const Color heroBlueBottom = Color(0xFF1D4ED8);
  static const Color pageBlue50 = Color(0xFFEFF6FF);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
}

/// Material 3 + DM Sans for Document Seeker.
ThemeData buildDocumentSeekerTheme() {
  const seed = Color(0xFF1D4ED8);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    surface: Colors.white,
    surfaceContainerLowest: TshijukaBranding.pageBlue50,
  );

  final baseText = GoogleFonts.dmSansTextTheme().apply(
    bodyColor: const Color(0xFF0F172A),
    displayColor: const Color(0xFF020617),
  );

  final textTheme = baseText.copyWith(
    displaySmall: baseText.displaySmall?.copyWith(height: 1.15, letterSpacing: -0.5),
    headlineLarge: baseText.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.45,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.35,
    ),
    headlineSmall: baseText.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.3,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.28,
      letterSpacing: -0.2,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: -0.15,
    ),
    titleSmall: baseText.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: baseText.bodyMedium?.copyWith(height: 1.45),
    bodySmall: baseText.bodySmall?.copyWith(height: 1.4, letterSpacing: 0.08),
    labelLarge: baseText.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.2,
    ),
    labelMedium: baseText.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.12,
      height: 1.2,
    ),
    labelSmall: baseText.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      height: 1.25,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.65)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
      floatingLabelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      errorStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.error,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
  );
}

