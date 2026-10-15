import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:french_pass/core/theme/app_palette.dart';

export 'package:french_pass/core/theme/app_palette.dart';

/// "Parisian elegant" design system: warm dark ground, gold accent, terracotta
/// secondary. Both themes are *selected* — the light theme is its own set of
/// steps rather than an inverted dark theme, so gold stays legible on white.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);
  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final texts = _textTheme(p);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      extensions: [p],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.gold,
        onPrimary: p.onGold,
        primaryContainer: p.surfaceAlt,
        onPrimaryContainer: p.textPrimary,
        secondary: p.terracotta,
        onSecondary: brightness == Brightness.dark ? p.bg : Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        surfaceContainerHighest: p.surfaceAlt,
        onSurfaceVariant: p.textSecondary,
        outline: p.border,
        outlineVariant: p.border,
        error: p.critical,
        onError: brightness == Brightness.dark ? p.bg : Colors.white,
      ),
      textTheme: texts,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.textSecondary, size: 22),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: p.border),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texts.titleLarge,
        iconTheme: IconThemeData(color: p.textSecondary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.gold,
          foregroundColor: p.onGold,
          disabledBackgroundColor: p.surfaceAlt,
          disabledForegroundColor: p.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md)),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl, vertical: Insets.lg),
          textStyle: GoogleFonts.lato(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.borderStrong),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md)),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.lg),
          textStyle: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.gold,
          textStyle: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        selectedColor: p.gold.withValues(alpha: 0.16),
        labelStyle: GoogleFonts.lato(
            color: p.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.lato(color: p.gold, fontSize: 12),
        side: BorderSide(color: p.border),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(Radii.pill))),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 6),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.bgAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        // The selected tab shows in its icon and label, not a pill that
        // competes with the content.
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(
              size: 23,
              color: states.contains(WidgetState.selected)
                  ? p.gold
                  : p.textMuted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.lato(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? p.textPrimary : p.textMuted,
          );
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceAlt,
        contentTextStyle: GoogleFonts.lato(color: p.textPrimary, fontSize: 14),
        actionTextColor: p.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.xl)),
        titleTextStyle: texts.titleLarge,
        contentTextStyle: texts.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        titleTextStyle: texts.titleMedium,
        subtitleTextStyle: texts.bodySmall,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.onGold : p.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.gold : p.surfaceAlt),
        trackOutlineColor: WidgetStateProperty.all(p.border),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: p.gold,
        inactiveTrackColor: p.surfaceAlt,
        thumbColor: p.gold,
        overlayColor: p.gold.withValues(alpha: 0.12),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.gold,
        linearTrackColor: p.surfaceAlt,
        circularTrackColor: p.surfaceAlt,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: p.border),
        ),
        textStyle: GoogleFonts.lato(color: p.textPrimary, fontSize: 12),
      ),
    );
  }

  // ── Type scale ────────────────────────────────────────────────────────────
  // Playfair Display for French words and headings, Lato for UI, Crimson Pro
  // for IPA transcriptions.
  static TextTheme _textTheme(AppPalette p) => TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
            fontSize: 60,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: -1.5,
            color: p.textPrimary),
        displayMedium: GoogleFonts.playfairDisplay(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -1,
            color: p.textPrimary),
        displaySmall: GoogleFonts.playfairDisplay(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.5,
            color: p.textPrimary),
        headlineLarge: GoogleFonts.playfairDisplay(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.3,
            color: p.textPrimary),
        headlineMedium: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: p.textPrimary),
        headlineSmall: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: p.textPrimary),
        titleLarge: GoogleFonts.lato(
            fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary),
        titleMedium: GoogleFonts.lato(
            fontSize: 15, fontWeight: FontWeight.w600, color: p.textPrimary),
        titleSmall: GoogleFonts.lato(
            fontSize: 13, fontWeight: FontWeight.w600, color: p.textSecondary),
        bodyLarge: GoogleFonts.lato(
            fontSize: 16, height: 1.45, color: p.textPrimary),
        bodyMedium: GoogleFonts.lato(
            fontSize: 14, height: 1.45, color: p.textSecondary),
        bodySmall: GoogleFonts.lato(
            fontSize: 13, height: 1.4, color: p.textMuted),
        labelLarge: GoogleFonts.lato(
            fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary),
        labelMedium: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: p.textSecondary),
        labelSmall: GoogleFonts.lato(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: p.textMuted),
      );

  /// French text as the hero of a screen: the word being learned, a phrase
  /// to say. Serif in the learner's ink, never gold, so it reads as
  /// content rather than decoration.
  static TextStyle french(BuildContext context, {double size = 28}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: size >= 28 ? -0.4 : 0,
        color: context.palette.textPrimary,
      );

  /// Style for IPA transcriptions.
  static TextStyle ipa(BuildContext context, {double size = 16}) =>
      GoogleFonts.crimsonPro(
        fontSize: size,
        fontStyle: FontStyle.italic,
        color: context.palette.textSecondary,
      );

  /// Uppercase eyebrow label used above sections.
  static TextStyle eyebrow(BuildContext context) => GoogleFonts.lato(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: context.palette.textMuted,
      );
}
