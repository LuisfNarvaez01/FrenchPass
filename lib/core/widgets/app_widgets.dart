import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:french_pass/core/theme/app_theme.dart';

/// Page shell: paints the warm vertical ground plus a soft gold bloom at the
/// top so every screen shares one atmosphere.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bgAlt, p.bg],
          stops: const [0, 0.45],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -160,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      p.gold.withValues(alpha: 0.10),
                      p.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // A second, cooler bloom low on the opposite side keeps the warm
          // top glow from reading as a single flat spotlight.
          Positioned(
            bottom: -200,
            left: -140,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      p.terracotta.withValues(alpha: 0.05),
                      p.terracotta.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// The standard surface: 1px warm border, no elevation, generous radius.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool accent;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.onTap,
    this.accent = false,
    this.radius = Radii.lg,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final decoration = BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accent ? p.gold.withValues(alpha: 0.35) : p.border,
      ),
      boxShadow: accent
          ? [
              BoxShadow(
                color: p.gold.withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return _PressScale(
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Wraps a tappable surface with a subtle press-down scale, so taps across
/// the app read as physical rather than flat. Purely cosmetic — the actual
/// tap handling stays on the child's own gesture detector (`InkWell`,
/// `GestureDetector`, …); this only listens for down/up/cancel to drive the
/// scale, never consuming the tap itself.
class _PressScale extends StatefulWidget {
  final Widget child;
  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: Motion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Eyebrow + title, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!.toUpperCase(), style: AppTheme.eyebrow(context)),
                const SizedBox(height: Insets.xs),
              ],
              Text(title, style: context.texts.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: context.texts.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// The back affordance every pushed screen shares. `maybePop` works for both
/// go_router routes and plain pushed routes.
class AppBackButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const AppBackButton({
    super.key,
    this.icon = Icons.arrow_back_ios_new_rounded,
    this.tooltip = 'Volver',
    this.onPressed,
  });

  /// The "close" variant for screens that end a flow rather than step back.
  const AppBackButton.close({super.key, this.onPressed})
      : icon = Icons.close_rounded,
        tooltip = 'Cerrar';

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed ?? () => Navigator.maybePop(context),
      );
}

/// Pinned header for pushed, scrolling screens: back button, title, actions.
class AppSliverBar extends StatelessWidget {
  final Widget title;
  final List<Widget>? actions;

  const AppSliverBar({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) => SliverAppBar(
        pinned: true,
        backgroundColor: context.palette.bg,
        surfaceTintColor: Colors.transparent,
        leading: const AppBackButton(),
        title: title,
        actions: actions,
      );
}

/// Non-scrolling header for full-screen flows (practice, result).
class AppTopBar extends StatelessWidget {
  final String title;
  final AppBackButton leading;

  const AppTopBar({
    super.key,
    required this.title,
    this.leading = const AppBackButton(),
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        child: Row(
          children: [
            leading,
            const SizedBox(width: Insets.xs),
            Expanded(
              child: Text(title,
                  style: context.texts.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

/// A one-line status message in a card: icon plus a short sentence. For
/// "nothing to do here" moments that are too small for a full [EmptyState].
class InfoNotice extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String message;
  final double iconSize;

  const InfoNotice({
    super.key,
    required this.icon,
    required this.message,
    this.iconColor,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? context.palette.textMuted, size: iconSize),
            const SizedBox(width: Insets.md),
            Expanded(child: Text(message, style: context.texts.bodySmall)),
          ],
        ),
      );
}

/// Small rounded label. Defaults to a muted surface; [tone] tints it.
class Pill extends StatelessWidget {
  final String label;
  final Color? tone;
  final IconData? icon;
  final bool dense;

  const Pill({
    super.key,
    required this.label,
    this.tone,
    this.icon,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = tone ?? p.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Insets.sm : Insets.md,
        vertical: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: c),
            const SizedBox(width: Insets.xs),
          ],
          Text(
            label,
            style:
                (dense ? context.texts.labelSmall : context.texts.labelMedium)
                    ?.copyWith(color: c),
          ),
        ],
      ),
    );
  }
}

/// A headline number with its label — the right form when there is one value
/// to report and no shape to show.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final String? unit;
  final IconData? icon;
  final Color? tone;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.icon,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = tone ?? p.gold;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: c),
            const SizedBox(height: Insets.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: context.texts.headlineLarge?.copyWith(color: c),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(unit!,
                    style: context.texts.titleSmall?.copyWith(color: c)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: context.texts.bodySmall),
        ],
      ),
    );
  }
}

/// Status chip that carries meaning in the label and icon, not only in colour.
class StatusChip extends StatelessWidget {
  final double score;
  const StatusChip({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Pill(
      label: AppPalette.statusLabel(score),
      icon: AppPalette.statusIcon(score),
      tone: context.palette.statusFor(score),
      dense: true,
    );
  }
}

/// Circular score gauge with an animated sweep.
class ScoreRing extends StatelessWidget {
  final double score;
  final double size;
  final double stroke;
  final String? caption;

  const ScoreRing({
    super.key,
    required this.score,
    this.size = 164,
    this.stroke = 11,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = p.statusFor(score);
    // The painted ring and the animating number mean nothing to a screen
    // reader, so announce the final score once instead.
    return Semantics(
      label: caption ?? 'Puntuación',
      value: '${(score.clamp(0.0, 1.0) * 100).round()} %',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: score.clamp(0.0, 1.0)),
        duration: Motion.slow,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: value,
              track: p.surfaceAlt,
              tone: tone,
              stroke: stroke,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}%',
                    style: context.texts.displaySmall
                        ?.copyWith(color: tone, fontWeight: FontWeight.w700),
                  ),
                  if (caption != null)
                    Text(caption!, style: context.texts.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color track;
  final Color tone;
  final double stroke;

  _RingPainter({
    required this.value,
    required this.track,
    required this.tone,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = tone;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.tone != tone || old.track != track;
}

/// Thin labelled meter — a row of these reads as one scale.
class MeterRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? tone;

  const MeterRow({
    super.key,
    required this.label,
    required this.value,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = tone ?? p.gold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: context.texts.bodyMedium),
            Text('${(value * 100).round()}%',
                style: context.texts.labelLarge?.copyWith(color: c)),
          ],
        ),
        const SizedBox(height: Insets.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: Motion.slow,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: p.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(c),
            ),
          ),
        ),
      ],
    );
  }
}

/// Empty / zero-data state with an optional call to action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: Sizes.emptyIcon,
              height: Sizes.emptyIcon,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surfaceAlt,
                border: Border.all(color: p.border),
              ),
              child: Icon(icon, size: 30, color: p.textMuted),
            ),
            const SizedBox(height: Insets.xl),
            Text(title,
                style: context.texts.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: Insets.sm),
            Text(message,
                style: context.texts.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Insets.xl),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-bleed loading state that matches the page ground.
class AppLoader extends StatelessWidget {
  final String? message;
  const AppLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: context.palette.gold),
          ),
          if (message != null) ...[
            const SizedBox(height: Insets.lg),
            Text(message!, style: context.texts.bodySmall),
          ],
        ],
      ),
    );
  }
}
