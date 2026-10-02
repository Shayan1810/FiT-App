import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Nebula — the coach's animated 3D "face": a glowing, slowly turning sphere
/// with swirling inner bands and a specular highlight, breathing gently.
/// Pure CustomPainter; no images or 3D engine needed.
class NebulaOrb extends StatefulWidget {
  const NebulaOrb({super.key, this.size = 120, this.energy = 0.7});

  final double size;

  /// 0–1: higher = faster swirl & brighter glow (maps readiness).
  final double energy;

  @override
  State<NebulaOrb> createState() => _NebulaOrbState();
}

class _NebulaOrbState extends State<NebulaOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) == true;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _OrbPainter(still ? 0.15 : _c.value, widget.energy)),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t, this.energy);
  final double t;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final breathe = 1 + 0.035 * math.sin(t * 2 * math.pi * 2);
    final r = size.width * 0.36 * breathe;

    // Outer glow halo.
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.25 + 0.2 * energy),
            AppColors.primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.35)),
    );

    // Ground shadow (sells the "floating" sphere).
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, r * 1.12), width: r * 1.3, height: r * 0.22),
      Paint()
        ..color = AppColors.primaryDeep.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final sphere = Rect.fromCircle(center: c, radius: r);
    // Body: off-centre radial gradient = lit sphere.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.0,
          colors: [
            Color.lerp(AppColors.primaryLight, Colors.white, 0.85)!,
            AppColors.primaryLight,
            AppColors.primary,
            Color.lerp(AppColors.primaryDeep, Colors.black, 0.35)!,
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ).createShader(sphere),
    );

    // Swirling inner bands (clipped to the sphere).
    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));
    final spin = t * 2 * math.pi * (0.6 + energy);
    for (var i = 0; i < 3; i++) {
      final a = spin + i * 2.1;
      final band = Rect.fromCenter(
        center: c.translate(math.cos(a) * r * 0.25, math.sin(a * 0.7) * r * 0.2),
        width: r * 2.2,
        height: r * (0.55 + 0.15 * i),
      );
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a * 0.5 + i);
      canvas.translate(-c.dx, -c.dy);
      canvas.drawOval(
        band,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.10
          ..color = Colors.white.withValues(alpha: 0.10 + 0.05 * i)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
      );
      canvas.restore();
    }
    canvas.restore();

    // Rim light (bottom-right) for depth.
    canvas.drawArc(
      sphere.deflate(1.5),
      -0.2,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-r * 0.35, -r * 0.42), width: r * 0.55, height: r * 0.32),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
    canvas.drawCircle(c.translate(-r * 0.42, -r * 0.48), r * 0.06, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t || old.energy != energy;
}
