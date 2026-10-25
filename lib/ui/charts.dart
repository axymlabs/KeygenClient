import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class DonutSegment {
  const DonutSegment(this.value, this.color);
  final double value;
  final Color color;
}

/// Ring chart that sweeps in on first paint, with a figure in the middle.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    required this.centerValue,
    required this.centerLabel,
    this.size = 140,
  });

  final List<DonutSegment> segments;
  final String centerValue;
  final String centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          painter: _DonutPainter(segments, cs.outlineVariant, t),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(centerValue,
                  style: AppTheme.mono(context,
                      size: 28, weight: FontWeight.w600)),
              Text(centerLabel.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.segments, this.track, this.progress);
  final List<DonutSegment> segments;
  final Color track;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = track);

    final total = segments.fold<double>(0, (a, s) => a + s.value);
    if (total == 0) return;
    const gap = 0.045; // radians between segments
    var start = -math.pi / 2;
    final multi = segments.where((s) => s.value > 0).length > 1;
    for (final s in segments) {
      if (s.value <= 0) continue;
      final full = s.value / total * math.pi * 2;
      final sweep = math.max(0.0, full - (multi ? gap : 0)) * progress;
      canvas.drawArc(arcRect, start + (multi ? gap / 2 : 0), sweep, false,
          paint..color = s.color);
      start += full;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.track != track;
}

/// Minimal bar chart with rounded tops, a hairline baseline and sparse labels.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 120,
    this.color,
    this.highlightLast = false,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final Color? color;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = color ?? cs.primary;
    final maxV = values.fold<double>(0, math.max);
    return Column(children: [
      SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            size: Size.infinite,
            painter: _BarPainter(values, maxV, base, cs.outlineVariant,
                cs.onSurfaceVariant, highlightLast, t),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        for (final (i, l) in labels.indexed)
          Expanded(
            child: Text(
              (labels.length <= 8 || i % 3 == 0 || i == labels.length - 1)
                  ? l
                  : '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style:
                  AppTheme.mono(context, size: 10, color: cs.onSurfaceVariant),
            ),
          ),
      ]),
    ]);
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.values, this.maxV, this.color, this.line, this.muted,
      this.highlightLast, this.t);
  final List<double> values;
  final double maxV;
  final Color color;
  final Color line;
  final Color muted;
  final bool highlightLast;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final slot = size.width / values.length;
    final barW = math.min(slot * 0.56, 28.0);
    final chartH = size.height - 1;

    // Faint guide lines at 50% and 100%.
    final guide = Paint()
      ..color = line.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = chartH - chartH * f;
      canvas.drawLine(
          Offset(0, y.clamp(0.5, chartH)),
          Offset(size.width, y.clamp(0.5, chartH)),
          f == 0
              ? (Paint()
                ..color = line
                ..strokeWidth = 1)
              : guide);
    }

    for (final (i, v) in values.indexed) {
      final h = maxV == 0 ? 0.0 : (v / maxV) * (chartH - 6) * t;
      final x = slot * i + (slot - barW) / 2;
      final isLast = highlightLast && i == values.length - 1;
      final empty = v == 0;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, chartH - math.max(h, empty ? 2 : 3), barW,
            math.max(h, empty ? 2 : 3)),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = empty
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isLast || !highlightLast
                        ? color
                        : color.withValues(alpha: 0.75),
                    color.withValues(alpha: 0.35),
                  ],
                ).createShader(rect.outerRect)
          ..color = empty ? line : color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.t != t || old.values != values || old.color != color;
}

/// Smooth line with a gradient area underneath and a glowing end point.
class LineChart extends StatelessWidget {
  const LineChart(
      {super.key, required this.values, this.color, this.height = 96});
  final List<double> values;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter:
              _LinePainter(values, color ?? cs.primary, cs.outlineVariant, t),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.color, this.grid, this.t);
  final List<double> values;
  final Color color;
  final Color grid;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.fold<double>(0, math.max);
    final minV = values.fold<double>(maxV, math.min);
    final range = math.max(maxV - minV, 1);
    const padTop = 10.0;
    const padBottom = 4.0;
    final h = size.height - padTop - padBottom;
    final pts = [
      for (final (i, v) in values.indexed)
        Offset(size.width * i / (values.length - 1),
            padTop + h - (v - minV) / range * h),
    ];
    for (final f in [0.25, 0.5, 0.75]) {
      canvas.drawLine(
          Offset(0, size.height * f),
          Offset(size.width, size.height * f),
          Paint()
            ..color = grid.withValues(alpha: 0.5)
            ..strokeWidth = 1);
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i], p1 = pts[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
    final area = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    if (t > 0.98) {
      final end = pts.last;
      canvas.drawCircle(end, 9, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(end, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.t != t || old.values != values || old.color != color;
}

/// Circular progress ring with a figure in the middle.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.progress,
    required this.color,
    required this.center,
    this.size = 96,
    this.stroke = 9,
  });
  final double progress;
  final Color color;
  final Widget center;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, color, track, stroke),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track, this.stroke);
  final double v;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    if (v > 0) {
      canvas.drawArc(
          rect, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}
