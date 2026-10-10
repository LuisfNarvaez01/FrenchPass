import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:french_pass/core/theme/app_theme.dart';

/// One point of a time series.
class ChartPoint {
  final String label;
  final double value;
  final bool highlight;

  const ChartPoint({
    required this.label,
    required this.value,
    this.highlight = false,
  });
}

/// Vertical bars for a count-per-day series.
///
/// One series, so there is no legend — the section title names it. Magnitude is
/// encoded by bar length only; the single gold hue is constant across bars and
/// never recoloured by rank. Tap a bar for its value (the touch equivalent of
/// hover); the current day is also direct-labelled so the common read needs no
/// interaction at all.
class WeeklyBars extends StatefulWidget {
  final List<ChartPoint> points;
  final String unit;
  final double height;

  const WeeklyBars({
    super.key,
    required this.points,
    this.unit = '',
    this.height = 132,
  });

  @override
  State<WeeklyBars> createState() => _WeeklyBarsState();
}

class _WeeklyBarsState extends State<WeeklyBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxValue = widget.points.fold<double>(
        0, (m, pt) => math.max(m, pt.value));
    // A flat-zero series still needs a baseline to read against.
    final scaleMax = maxValue <= 0 ? 1.0 : maxValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = widget.points.length;
        final slot = constraints.maxWidth / count;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final i = (d.localPosition.dx / slot).floor().clamp(0, count - 1);
            setState(() => _selected = _selected == i ? null : i);
          },
          child: SizedBox(
            height: widget.height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: _Bar(
                      point: widget.points[i],
                      fraction: widget.points[i].value / scaleMax,
                      showValue: _selected == i ||
                          (_selected == null && widget.points[i].highlight),
                      unit: widget.unit,
                      tone: widget.points[i].highlight ? p.gold : p.goldDim,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final ChartPoint point;
  final double fraction;
  final bool showValue;
  final String unit;
  final Color tone;

  const _Bar({
    required this.point,
    required this.fraction,
    required this.showValue,
    required this.unit,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Direct label, selectively — never a number on every bar.
        SizedBox(
          height: 16,
          child: showValue
              ? Text(
                  '${point.value.round()}$unit',
                  style: context.texts.labelSmall?.copyWith(
                      color: tone, letterSpacing: 0, fontSize: 11),
                )
              : null,
        ),
        const SizedBox(height: Insets.xs),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              // Keep a 2px sliver visible at zero so the category still reads.
              heightFactor: fraction <= 0 ? 0.015 : fraction.clamp(0.015, 1.0),
              widthFactor: 1,
              child: Padding(
                // 2px of surface between adjacent bars.
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.slow,
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Transform.scale(
                    scaleY: t,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fraction <= 0 ? p.border : tone,
                      // Rounded data-end, square baseline end.
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          point.label,
          style: context.texts.labelSmall?.copyWith(
            color: point.highlight ? p.textSecondary : p.textMuted,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

/// Score-over-time line with a soft area fill.
///
/// 2px stroke, 8px markers, recessive reference gridlines at 0/50/100%, and a
/// drag crosshair that reports the value under the finger.
class TrendLine extends StatefulWidget {
  final List<ChartPoint> points;
  final double height;

  const TrendLine({super.key, required this.points, this.height = 160});

  @override
  State<TrendLine> createState() => _TrendLineState();
}

class _TrendLineState extends State<TrendLine> {
  int? _active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (widget.points.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('Practica al menos dos días para ver tu tendencia.',
              style: context.texts.bodySmall, textAlign: TextAlign.center),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final count = widget.points.length;
        void pick(Offset local) {
          final i = ((local.dx / w) * (count - 1)).round().clamp(0, count - 1);
          setState(() => _active = i);
        }

        return GestureDetector(
          onTapDown: (d) => pick(d.localPosition),
          onHorizontalDragUpdate: (d) => pick(d.localPosition),
          onHorizontalDragEnd: (_) => setState(() => _active = null),
          onTapUp: (_) => setState(() => _active = null),
          child: SizedBox(
            height: widget.height,
            width: w,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Motion.slow,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                painter: _TrendPainter(
                  points: widget.points,
                  progress: t,
                  active: _active,
                  line: p.gold,
                  fillTop: p.gold.withValues(alpha: 0.22),
                  fillBottom: p.gold.withValues(alpha: 0.0),
                  grid: p.border,
                  surface: p.surface,
                  labelStyle: context.texts.labelSmall!
                      .copyWith(color: p.textMuted, letterSpacing: 0),
                  valueStyle: context.texts.labelLarge!.copyWith(color: p.gold),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<ChartPoint> points;
  final double progress;
  final int? active;
  final Color line;
  final Color fillTop;
  final Color fillBottom;
  final Color grid;
  final Color surface;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  _TrendPainter({
    required this.points,
    required this.progress,
    required this.active,
    required this.line,
    required this.fillTop,
    required this.fillBottom,
    required this.grid,
    required this.surface,
    required this.labelStyle,
    required this.valueStyle,
  });

  static const _bottomGutter = 22.0;
  static const _topGutter = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotH = size.height - _bottomGutter - _topGutter;
    final plotW = size.width;
    double xOf(int i) => plotW * i / (points.length - 1);
    double yOf(double v) => _topGutter + plotH * (1 - v.clamp(0.0, 1.0));

    // Recessive reference lines. Values are 0–1 scores, so the scale is fixed
    // and a single axis is enough — never a second y-scale.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [0.0, 0.5, 1.0]) {
      canvas.drawLine(
          Offset(0, yOf(v)), Offset(plotW, yOf(v)), gridPaint);
    }

    final path = Path();
    final area = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xOf(i);
      final y = yOf(points[i].value);
      if (i == 0) {
        path.moveTo(x, y);
        area.moveTo(x, yOf(0));
        area.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        area.lineTo(x, y);
      }
    }
    area.lineTo(xOf(points.length - 1), yOf(0));
    area.close();

    // Reveal left-to-right.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plotW * progress, size.height));

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillTop, fillBottom],
        ).createShader(Rect.fromLTWH(0, _topGutter, plotW, plotH)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = line,
    );

    // Markers: 8px, with a 2px surface ring so overlaps stay countable.
    for (var i = 0; i < points.length; i++) {
      final c = Offset(xOf(i), yOf(points[i].value));
      canvas.drawCircle(c, 5, Paint()..color = surface);
      canvas.drawCircle(c, 4, Paint()..color = line);
    }
    canvas.restore();

    // X labels: first, last, and the active one — never all of them.
    void drawLabel(String text, double cx, double cy, TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);
      final dx = (cx - tp.width / 2).clamp(0.0, plotW - tp.width);
      tp.paint(canvas, Offset(dx, cy));
    }

    drawLabel(points.first.label, xOf(0), size.height - _bottomGutter + 6,
        labelStyle);
    drawLabel(points.last.label, xOf(points.length - 1),
        size.height - _bottomGutter + 6, labelStyle);

    final i = active;
    if (i != null) {
      final x = xOf(i);
      final y = yOf(points[i].value);
      canvas.drawLine(
        Offset(x, _topGutter),
        Offset(x, _topGutter + plotH),
        Paint()
          ..color = line.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 7, Paint()..color = surface);
      canvas.drawCircle(Offset(x, y), 5.5, Paint()..color = line);
      drawLabel('${(points[i].value * 100).round()}%', x, 0, valueStyle);
      drawLabel(points[i].label, x, size.height - _bottomGutter + 6,
          labelStyle.copyWith(color: line));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.progress != progress || old.active != active || old.points != points;
}

/// Horizontal bars ranked by magnitude, one row per category.
///
/// Magnitude is doubly encoded — bar length plus a step off the single-hue
/// ordinal ramp — and every row carries a direct value label, so the ranking
/// survives both colour-vision deficiency and a greyscale print.
class RankedBars extends StatelessWidget {
  final List<ChartPoint> rows;
  final int maxRows;

  const RankedBars({super.key, required this.rows, this.maxRows = 6});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sorted = [...rows]..sort((a, b) => b.value.compareTo(a.value));
    final shown = sorted.take(maxRows).toList();
    final maxValue =
        shown.fold<double>(0, (m, r) => math.max(m, r.value));
    final scaleMax = maxValue <= 0 ? 1.0 : maxValue;

    return Column(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: Insets.md),
          Row(
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  shown[i].label,
                  style: context.texts.bodySmall
                      ?.copyWith(color: p.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: ClipRRect
                  (borderRadius: BorderRadius.circular(4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: 0,
                          end: (shown[i].value / scaleMax).clamp(0.02, 1.0)),
                      duration: Motion.slow,
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => FractionallySizedBox(
                        widthFactor: t,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: p.rampStep(shown[i].value / scaleMax),
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              SizedBox(
                width: 36,
                child: Text(
                  '${shown[i].value.round()}',
                  textAlign: TextAlign.right,
                  style: context.texts.labelMedium
                      ?.copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
