import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/theme/app_theme.dart';

/// The FrenchPass mascot: a shiba in a beret, with a moustache and a
/// baguette, cut out as a sticker.
///
/// It only shows up when the learner has earned it -- a word said clearly,
/// a conversation finished -- so it stays a reward rather than wallpaper.
class MascotSticker extends StatelessWidget {
  final double size;

  /// Resting tilt in radians; stickers are never stuck on perfectly
  /// straight.
  final double tilt;

  const MascotSticker({super.key, this.size = 96, this.tilt = -0.08});

  static const asset = 'assets/images/mascot.png';

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Perrito francés con boina y baguette',
      ),
    );
  }
}

/// The sticker being slapped on: it lands from slightly above and larger,
/// settles at its tilt, and throws a small burst of gold flecks -- one
/// authored moment, played once. With reduced motion it simply fades in.
class MascotCelebration extends StatelessWidget {
  final double size;
  final String? caption;
  final Duration delay;

  const MascotCelebration({
    super.key,
    this.size = 120,
    this.caption,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final calm = MediaQuery.disableAnimationsOf(context);

    final sticker = SizedBox(
      width: size * 1.5,
      height: size * 1.3,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (!calm)
            Positioned.fill(
              child: IgnorePointer(
                child: _Flecks(color: p.gold, accent: p.terracotta)
                    .animate(delay: delay + 260.ms)
                    .custom(
                      duration: 700.ms,
                      curve: Curves.easeOutCubic,
                      builder: (_, t, child) =>
                          _FlecksProgress(t: t, child: child),
                    ),
              ),
            ),
          MascotSticker(size: size),
        ],
      ),
    );

    final animated = calm
        ? sticker.animate(delay: delay).fadeIn(duration: Motion.base)
        : sticker
            .animate(delay: delay)
            .fadeIn(duration: 120.ms)
            .scaleXY(
              begin: 1.35,
              end: 1,
              duration: 320.ms,
              curve: const Cubic(0.16, 1, 0.3, 1),
            )
            .rotate(
              begin: -0.035,
              end: 0,
              duration: 420.ms,
              curve: const Cubic(0.16, 1, 0.3, 1),
            )
            .moveY(begin: -18, end: 0, duration: 320.ms)
            // A small wiggle once it lands, like a pat on the back.
            .then(delay: 200.ms)
            .rotate(begin: 0, end: 0.012, duration: 140.ms)
            .then()
            .rotate(begin: 0, end: -0.012, duration: 160.ms);

    if (caption == null) return animated;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        animated,
        _Bubble(text: caption!)
            .animate(delay: delay + 380.ms)
            .fadeIn(duration: Motion.fast)
            .moveY(begin: 6, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
      decoration: BoxDecoration(
        color: p.gold,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: [
          BoxShadow(
            color: p.gold.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: context.texts.titleMedium?.copyWith(
          color: p.onGold,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Passes the burst progress down to [_Flecks] without rebuilding the
/// sticker.
class _FlecksProgress extends InheritedWidget {
  final double t;
  const _FlecksProgress({required this.t, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FlecksProgress>()?.t ?? 1;

  @override
  bool updateShouldNotify(_FlecksProgress old) => old.t != t;
}

class _Flecks extends StatelessWidget {
  final Color color;
  final Color accent;
  const _Flecks({required this.color, required this.accent});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _FlecksPainter(
          t: _FlecksProgress.of(context),
          color: color,
          accent: accent,
        ),
      );
}

class _FlecksPainter extends CustomPainter {
  final double t;
  final Color color;
  final Color accent;
  _FlecksPainter({required this.t, required this.color, required this.accent});

  static const _count = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final centre = size.center(Offset.zero);
    final reach = size.shortestSide * 0.62;
    final fade = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < _count; i++) {
      // Irregular spacing and length so it reads as a burst, not a clock.
      final angle = (i / _count) * 2 * math.pi + (i.isEven ? 0.18 : -0.1);
      final len = 6.0 + (i % 3) * 4;
      final r0 = reach * (0.55 + 0.45 * t) + (i % 2) * 6;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final paint = Paint()
        ..color = (i % 4 == 0 ? accent : color).withValues(alpha: fade)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(centre + dir * r0, centre + dir * (r0 + len), paint);
    }
  }

  @override
  bool shouldRepaint(_FlecksPainter old) => old.t != t;
}

/// A quick mascot pop for a success inside a screen that keeps going (a
/// phrase said clearly while reviewing): it rises from the bottom edge,
/// says its line and leaves on its own. Never blocks a tap.
void showMascotToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _MascotToast(
      message: message,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _MascotToast extends StatelessWidget {
  final String message;
  final VoidCallback onDone;
  const _MascotToast({required this.message, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom + Insets.xxl;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const MascotSticker(size: 72),
        const SizedBox(width: Insets.xs),
        _Bubble(text: message),
      ],
    );

    final animated = calm
        ? content
            .animate(onComplete: (_) => onDone())
            .fadeIn(duration: Motion.fast)
            .then(delay: 1600.ms)
            .fadeOut(duration: Motion.fast)
        : content
            .animate(onComplete: (_) => onDone())
            .moveY(
                begin: 90,
                end: 0,
                duration: 380.ms,
                curve: const Cubic(0.16, 1, 0.3, 1))
            .fadeIn(duration: 160.ms)
            .then(delay: 1500.ms)
            .moveY(begin: 0, end: 90, duration: 240.ms, curve: Curves.easeIn)
            .fadeOut(duration: 240.ms);

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Material(
            type: MaterialType.transparency,
            child: Center(child: animated),
          ),
        ),
      ),
    );
  }
}
