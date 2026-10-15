import 'package:flutter/material.dart';

import 'package:french_pass/core/theme/app_theme.dart';

/// FrenchPass's own shape: a ticket, a *pass*. A main part and a stub,
/// joined by a perforated line with a half-moon notch bitten out of each
/// side. Kept for the app's special pieces (the word of the day, the next
/// conversation, a finished lesson) so it stays recognisable, not
/// wallpaper.
class PassCard extends StatelessWidget {
  final Widget main;
  final Widget stub;
  final EdgeInsetsGeometry mainPadding;
  final EdgeInsetsGeometry stubPadding;

  /// A warm gold glow, for the one pass that is the screen's focus.
  final bool accent;

  const PassCard({
    super.key,
    required this.main,
    required this.stub,
    this.mainPadding = const EdgeInsets.all(Insets.xl),
    this.stubPadding =
        const EdgeInsets.fromLTRB(Insets.xl, Insets.lg, Insets.xl, Insets.md),
    this.accent = false,
  });

  static const _notch = 10.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // No outline: it would cross the seam. The pass stands off the page by
    // its lighter tone in the dark theme and by a soft shadow in the light.
    final shadows = [
      BoxShadow(
        color: accent
            ? p.gold.withValues(alpha: dark ? 0.10 : 0.14)
            : Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
    ShapeDecoration part({required bool top}) => ShapeDecoration(
          color: p.surface,
          shadows: shadows,
          shape: PassBorder(
            notchTop: !top,
            notchBottom: top,
            notch: _notch,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: part(top: true),
          child: Padding(padding: mainPadding, child: main),
        ),
        // The perforation sits on the seam, between the two notches.
        Container(
          color: p.surface,
          margin: const EdgeInsets.symmetric(horizontal: _notch),
          height: 1,
          child: CustomPaint(painter: _Perforation(p.borderStrong)),
        ),
        DecoratedBox(
          decoration: part(top: false),
          child: Padding(padding: stubPadding, child: stub),
        ),
      ],
    );
  }
}

class _Perforation extends CustomPainter {
  final Color color;
  _Perforation(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dash = 4.0, gap = 5.0;
    for (var x = Insets.sm; x < size.width - Insets.sm; x += dash + gap) {
      canvas.drawLine(
          Offset(x, 0.5), Offset((x + dash).clamp(0, size.width), 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_Perforation old) => old.color != color;
}

/// A rounded rectangle whose top or bottom corners are bitten in (concave),
/// like the edge of a ticket where it tears off.
class PassBorder extends ShapeBorder {
  final bool notchTop;
  final bool notchBottom;
  final double notch;
  final double radius;
  final BorderSide side;

  const PassBorder({
    this.notchTop = false,
    this.notchBottom = false,
    this.notch = 10,
    this.radius = Radii.xl,
    this.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    final top = notchTop ? notch : radius;
    final bottom = notchBottom ? notch : radius;
    final rTop = Radius.circular(top);
    final rBottom = Radius.circular(bottom);
    // Concave corners curve the other way round.
    return Path()
      ..moveTo(l, t + top)
      ..arcToPoint(Offset(l + top, t), radius: rTop, clockwise: !notchTop)
      ..lineTo(r - top, t)
      ..arcToPoint(Offset(r, t + top), radius: rTop, clockwise: !notchTop)
      ..lineTo(r, b - bottom)
      ..arcToPoint(Offset(r - bottom, b),
          radius: rBottom, clockwise: !notchBottom)
      ..lineTo(l + bottom, b)
      ..arcToPoint(Offset(l, b - bottom),
          radius: rBottom, clockwise: !notchBottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2)),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) => PassBorder(
        notchTop: notchTop,
        notchBottom: notchBottom,
        notch: notch * t,
        radius: radius * t,
        side: side.scale(t),
      );
}
