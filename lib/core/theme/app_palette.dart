import 'package:flutter/material.dart';

/// Semantic colour tokens for FrenchPass, resolved per brightness.
///
/// This lives in a [ThemeExtension] rather than in an `extension on ColorScheme`
/// so that every token is brightness-aware: reading `context.palette.surface`
/// in light mode returns a light surface instead of a hardcoded dark one.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  // ── Surfaces ──────────────────────────────────────────────────────────────
  final Color bg;
  final Color bgAlt;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;

  // ── Brand ─────────────────────────────────────────────────────────────────
  final Color gold;
  final Color goldBright;
  final Color goldDim;
  final Color terracotta;

  // ── Ink ───────────────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color onGold;

  // ── Status ────────────────────────────────────────────────────────────────
  /// Status colours are reserved for state (never reused as chart series) and
  /// are always shipped alongside an icon + label, never colour alone: the
  /// good/critical pair is indistinguishable under deuteranopia (validated
  /// ΔE 3.5), so the label is what carries the meaning.
  final Color good;
  final Color warning;
  final Color critical;

  // ── Data visualisation ────────────────────────────────────────────────────
  /// Single-hue ordinal ramp, light → dark, for magnitude encoding. Validated
  /// per mode: monotone lightness, ΔL ≥ 0.06 between steps, light end ≥ 2:1
  /// against the chart surface.
  final List<Color> goldRamp;

  const AppPalette({
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.gold,
    required this.goldBright,
    required this.goldDim,
    required this.terracotta,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.onGold,
    required this.good,
    required this.warning,
    required this.critical,
    required this.goldRamp,
  });

  /// "Noche parisina": ink blue-black ground, cream ink, gold kept for the
  /// one action or achievement on screen. Every text token clears WCAG AA
  /// (4.5:1) on bg, surface and surfaceAlt; each surface step is a visible
  /// lift over the one below, so layers read without borders.
  static const dark = AppPalette(
    bg: Color(0xFF0F1218),
    bgAlt: Color(0xFF141924),
    surface: Color(0xFF1A1F29),
    surfaceAlt: Color(0xFF252B37),
    border: Color(0xFF2A3140),
    borderStrong: Color(0xFF3B4456),
    gold: Color(0xFFD9AE55),
    goldBright: Color(0xFFE8C77F),
    goldDim: Color(0xFFA9843A),
    terracotta: Color(0xFFE0835A),
    textPrimary: Color(0xFFF4EFE6),
    textSecondary: Color(0xFFBDB6AA),
    textMuted: Color(0xFF9A9489),
    onGold: Color(0xFF17130B),
    good: Color(0xFF5BBF8E),
    warning: Color(0xFFE6B04A),
    critical: Color(0xFFE8828F),
    goldRamp: [
      Color(0xFF7A5F2A),
      Color(0xFFA07F3B),
      Color(0xFFC49A48),
      Color(0xFFD9AE55),
      Color(0xFFE8C77F),
    ],
  );

  /// Cream paper and dark ink; same roles as [dark]. Text tokens clear AA
  /// on bg and surface.
  static const light = AppPalette(
    bg: Color(0xFFFAF6EF),
    bgAlt: Color(0xFFF3ECE0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3ECE0),
    border: Color(0xFFE6DCCB),
    borderStrong: Color(0xFFD2C3AA),
    gold: Color(0xFF86601C),
    goldBright: Color(0xFFC49A3C),
    goldDim: Color(0xFF6E4F18),
    terracotta: Color(0xFF9A4A22),
    textPrimary: Color(0xFF2A231C),
    textSecondary: Color(0xFF5C5045),
    textMuted: Color(0xFF74685A),
    onGold: Color(0xFFFFFFFF),
    good: Color(0xFF2A7F5A),
    warning: Color(0xFF99650C),
    critical: Color(0xFFB23E52),
    goldRamp: [
      Color(0xFFD7B45E),
      Color(0xFFC49A3C),
      Color(0xFFA87F2C),
      Color(0xFF86601C),
      Color(0xFF6E4F18),
    ],
  );

  /// Picks the ramp step for a 0–1 magnitude.
  Color rampStep(double t) =>
      goldRamp[(t.clamp(0.0, 1.0) * (goldRamp.length - 1)).round()];

  /// Status colour for a 0–1 score. Always pair with [statusLabel].
  Color statusFor(double score) => switch (score) {
        >= 0.75 => good,
        >= 0.5 => warning,
        _ => critical,
      };

  static String statusLabel(double score) => switch (score) {
        >= 0.75 => 'Dominada',
        >= 0.5 => 'En progreso',
        _ => 'Por reforzar',
      };

  static IconData statusIcon(double score) => switch (score) {
        >= 0.75 => Icons.check_circle_rounded,
        >= 0.5 => Icons.trending_up_rounded,
        _ => Icons.error_outline_rounded,
      };

  @override
  AppPalette copyWith({
    Color? bg,
    Color? bgAlt,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? borderStrong,
    Color? gold,
    Color? goldBright,
    Color? goldDim,
    Color? terracotta,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? onGold,
    Color? good,
    Color? warning,
    Color? critical,
    List<Color>? goldRamp,
  }) =>
      AppPalette(
        bg: bg ?? this.bg,
        bgAlt: bgAlt ?? this.bgAlt,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        border: border ?? this.border,
        borderStrong: borderStrong ?? this.borderStrong,
        gold: gold ?? this.gold,
        goldBright: goldBright ?? this.goldBright,
        goldDim: goldDim ?? this.goldDim,
        terracotta: terracotta ?? this.terracotta,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        onGold: onGold ?? this.onGold,
        good: good ?? this.good,
        warning: warning ?? this.warning,
        critical: critical ?? this.critical,
        goldRamp: goldRamp ?? this.goldRamp,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: c(bg, other.bg),
      bgAlt: c(bgAlt, other.bgAlt),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      gold: c(gold, other.gold),
      goldBright: c(goldBright, other.goldBright),
      goldDim: c(goldDim, other.goldDim),
      terracotta: c(terracotta, other.terracotta),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      onGold: c(onGold, other.onGold),
      good: c(good, other.good),
      warning: c(warning, other.warning),
      critical: c(critical, other.critical),
      goldRamp: [
        for (var i = 0; i < goldRamp.length; i++)
          c(goldRamp[i], other.goldRamp[i]),
      ],
    );
  }
}

/// Spacing, radius and duration tokens — one scale, used everywhere.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const xxxl = 40.0;

  /// Horizontal page gutter.
  static const page = 20.0;
}

/// Fixed component dimensions -- the few sizes that are not spacing but still
/// need to agree across screens.
abstract final class Sizes {
  /// Height of the primary action buttons (listen / practice / save).
  static const actionHeight = 64.0;

  /// Big circular controls: the mic and the quiz replay disc.
  static const heroControl = 128.0;
  static const heroControlSm = 104.0;

  /// Icon disc on an empty state.
  static const emptyIcon = 72.0;

  /// Fixed label column beside a value (translations, ranked bars).
  static const labelColumn = 68.0;
  static const labelColumnWide = 104.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 450);

  /// Delay for the [step]th item of an entrance cascade -- one shared rhythm
  /// so every screen's sections settle in at the same pace.
  static Duration stagger(int step) => Duration(milliseconds: 40 * step);
}

extension PaletteOf on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get texts => Theme.of(this).textTheme;
}
