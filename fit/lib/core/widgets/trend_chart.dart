import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A point of a [TrendChart].
class TrendDatum {
  const TrendDatum(this.x, this.raw, this.trend);

  /// Any monotonic x value (e.g. days since start).
  final double x;
  final double raw;
  final double trend;
}

/// Weight trend chart: raw weigh-ins as 3D beads, the smoothed trend as a
/// thick glowing line with a gradient "shadow volume" beneath it.
class TrendChart extends StatelessWidget {
  TrendChart({super.key, required this.points, this.height = 180, Color? color})
    : color = color ?? AppColors.primary;

  final List<TrendDatum> points;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) =>
            CustomPaint(size: Size.infinite, painter: _TrendPainter(points, color, t)),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  /// Palette version at construction — forces a repaint on theme change.
  final int _paletteVersion = AppColors.version;

  _TrendPainter(this.points, this.color, this.t);
  final List<TrendDatum> points;
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final xs = points.map((p) => p.x);
    final ys = points.expand((p) => [p.raw, p.trend]);
    final minX = xs.reduce((a, b) => a < b ? a : b), maxX = xs.reduce((a, b) => a > b ? a : b);
    var minY = ys.reduce((a, b) => a < b ? a : b), maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(0.3, 5.0);
    minY -= pad;
    maxY += pad;
    const left = 34.0, bottom = 8.0, top = 8.0;
    final w = size.width - left - 8, h = size.height - top - bottom;
    Offset map(double x, double y) => Offset(
      left + (maxX == minX ? 0.5 : (x - minX) / (maxX - minX)) * w,
      top + (1 - (y - minY) / (maxY - minY)) * h,
    );

    // Y grid + labels.
    for (var i = 0; i <= 3; i++) {
      final v = minY + (maxY - minY) * i / 3;
      final y = map(minX, v).dy;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), Paint()..color = AppColors.divider);
      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(1),
          style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'Poppins'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final visible = (points.length * t).ceil().clamp(2, points.length);
    final trend = Path();
    for (var i = 0; i < visible; i++) {
      final o = map(points[i].x, points[i].trend);
      i == 0 ? trend.moveTo(o.dx, o.dy) : trend.lineTo(o.dx, o.dy);
    }
    final last = map(points[visible - 1].x, points[visible - 1].trend);
    final fill = Path.from(trend)
      ..lineTo(last.dx, top + h)
      ..lineTo(map(points.first.x, 0).dx, top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    // Glow under the line, then the line itself.
    canvas.drawPath(
      trend.shift(const Offset(0, 4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      trend,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Raw weigh-ins as small shaded beads.
    for (var i = 0; i < visible; i++) {
      final o = map(points[i].x, points[i].raw);
      canvas.drawCircle(o.translate(0.8, 1.5), 3.6, Paint()..color = Colors.black.withValues(alpha: 0.12));
      canvas.drawCircle(
        o,
        3.6,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [Colors.white, AppColors.slate600],
          ).createShader(Rect.fromCircle(center: o, radius: 3.6)),
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old._paletteVersion != _paletteVersion || old.t != t || old.points != points;
}
