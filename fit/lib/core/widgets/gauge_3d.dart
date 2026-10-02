import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Semicircular 3D gauge (readiness score, ACWR…).
///
/// A recessed track, a red→amber→green gradient arc, a needle with a drop
/// shadow and a domed metallic hub. The needle swings into place with an
/// overshoot.
class Gauge3D extends StatelessWidget {
  const Gauge3D({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.size = 220,
    this.label,
    this.caption,
    this.colors = const [AppColors.danger, AppColors.warning, AppColors.success],
  });

  final double value;
  final double min;
  final double max;
  final double size;

  /// Big text under the hub (defaults to the rounded value).
  final String? label;
  final String? caption;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final frac = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: frac),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.elasticOut,
        builder: (context, f, _) => CustomPaint(
          painter: _GaugePainter(f, colors),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label ?? value.round().toString(),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1),
                ),
                if (caption != null)
                  Text(caption!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  /// Palette version at construction — forces a repaint on theme change.
  final int _paletteVersion = AppColors.version;

  _GaugePainter(this.f, this.colors);
  final double f;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final c = Offset(size.width / 2, size.width / 2 * 0.98);
    final r = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Recessed track.
    canvas.drawArc(
      rect.shift(const Offset(0, 2)),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.background,
    );

    // Gradient value arc.
    if (f > 0.001) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * f,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.78
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: math.pi,
            endAngle: 2 * math.pi,
            colors: colors,
          ).createShader(rect),
      );
      // Rim highlight.
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + stroke * 0.25),
        math.pi,
        math.pi * f,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.6),
      );
    }

    // Tick marks.
    for (var i = 0; i <= 10; i++) {
      final a = math.pi + math.pi * i / 10;
      final o = c + Offset(math.cos(a), math.sin(a)) * (r - stroke * 0.85);
      final in2 = c + Offset(math.cos(a), math.sin(a)) * (r - stroke * (i % 5 == 0 ? 1.35 : 1.1));
      canvas.drawLine(
        o,
        in2,
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: 0.6)
          ..strokeWidth = i % 5 == 0 ? 2 : 1,
      );
    }

    // Needle with shadow.
    final a = math.pi + math.pi * f;
    final tip = c + Offset(math.cos(a), math.sin(a)) * (r - stroke * 0.4);
    final perp = Offset(-math.sin(a), math.cos(a)) * 5;
    final needle = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(c.dx + perp.dx, c.dy + perp.dy)
      ..lineTo(c.dx - perp.dx, c.dy - perp.dy)
      ..close();
    canvas.drawPath(
      needle.shift(const Offset(2, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(needle, Paint()..color = AppColors.slate900);

    // Domed hub.
    final hub = Rect.fromCircle(center: c, radius: 11);
    canvas.drawCircle(
      c.translate(1, 3),
      11,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      c,
      11,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Colors.white, AppColors.primaryLight, AppColors.primary],
        ).createShader(hub),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old._paletteVersion != _paletteVersion || old.f != f;
}
