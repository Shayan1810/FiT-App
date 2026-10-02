import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One ring of a [Ring3D] stack.
class RingSpec {
  const RingSpec({required this.progress, required this.color, this.label});

  /// 0…1 (values > 1 draw a second, brighter lap up to 2).
  final double progress;
  final Color color;
  final String? label;
}

/// Concentric, extruded progress rings (activity-ring style, but 3D):
/// a recessed groove for the track, a darker "side wall" under each arc,
/// a sweep-gradient face, a glossy rim highlight and a glowing end cap.
///
/// Animates from 0 to the target values on first build and on change.
class Ring3D extends StatelessWidget {
  const Ring3D({
    super.key,
    required this.rings,
    this.size = 160,
    this.stroke = 16,
    this.gap = 5,
    this.center,
  });

  final List<RingSpec> rings;
  final double size;
  final double stroke;
  final double gap;

  /// Widget drawn in the middle (e.g. kcal left).
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) =>
            CustomPaint(painter: _RingPainter(rings, stroke, gap, t), child: child),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  /// Palette version at construction — forces a repaint on theme change.
  final int _paletteVersion = AppColors.version;

  _RingPainter(this.rings, this.stroke, this.gap, this.t);
  final List<RingSpec> rings;
  final double stroke;
  final double gap;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < rings.length; i++) {
      final r = size.width / 2 - stroke / 2 - i * (stroke + gap) - 2;
      if (r <= stroke / 2) break;
      _paintRing(canvas, c, r, rings[i]);
    }
  }

  void _paintRing(Canvas canvas, Offset c, double r, RingSpec ring) {
    final rect = Rect.fromCircle(center: c, radius: r);

    // Recessed groove: dark inner shadow + light lower rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = ring.color.withValues(alpha: 0.10),
    );
    canvas.drawArc(
      rect.shift(const Offset(0, 1.5)),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.55
        ..color = Colors.black.withValues(alpha: 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    final p = (ring.progress.clamp(0.0, 2.0)) * t;
    if (p <= 0.001) return;
    final sweep = 2 * math.pi * math.min(p, 1.0);
    const start = -math.pi / 2;

    // Extrusion side wall: darker arc offset downwards.
    final dark = Color.lerp(ring.color, Colors.black, 0.35)!;
    canvas.drawArc(
      rect.shift(const Offset(0, 3)),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = dark.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Face with sweep gradient.
    final light = Color.lerp(ring.color, Colors.white, 0.35)!;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [light, ring.color, Color.lerp(ring.color, Colors.black, 0.12)!, light],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );

    // Over-target second lap.
    if (p > 1) {
      canvas.drawArc(
        rect,
        start,
        2 * math.pi * (p - 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.55
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // Glossy rim highlight along the outer edge.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r + stroke * 0.22),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // Glowing end cap.
    final endAngle = start + sweep;
    final cap = c + Offset(math.cos(endAngle) * r, math.sin(endAngle) * r);
    canvas.drawCircle(
      cap,
      stroke * 0.62,
      Paint()
        ..color = ring.color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      cap,
      stroke * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, ring.color],
          center: const Alignment(-0.4, -0.4),
        ).createShader(Rect.fromCircle(center: cap, radius: stroke * 0.42)),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old._paletteVersion != _paletteVersion || old.t != t || old.rings != rings;
}

/// Convenience: a single ring with a big value in the middle.
class SingleRing extends StatelessWidget {
  const SingleRing({
    super.key,
    required this.progress,
    required this.color,
    required this.center,
    this.size = 110,
    this.stroke = 12,
  });

  final double progress;
  final Color color;
  final Widget center;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => Ring3D(
    rings: [RingSpec(progress: progress, color: color)],
    size: size,
    stroke: stroke,
    center: center,
  );
}

/// Ring colours used by nutrition summaries.
final List<Color> kMacroRingColors = [AppColors.primary, AppColors.protein, AppColors.carbs, AppColors.fat];
