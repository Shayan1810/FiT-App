import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One column of a [Bars3D] chart.
class BarDatum {
  const BarDatum({required this.label, required this.value, this.value2, this.highlight = false});
  final String label;

  /// Primary series value.
  final double value;

  /// Optional second series (drawn as a twin bar).
  final double? value2;

  /// Draws the label bold (e.g. today).
  final bool highlight;
}

/// Isometric 3D bar chart. Each bar is a real "block": a gradient front
/// face, a darker right-hand side face and a lighter top face. Bars grow
/// from the floor with a staggered animation; an optional dashed target
/// line shows the goal.
class Bars3D extends StatelessWidget {
  Bars3D({
    super.key,
    required this.data,
    Color? color,
    Color? color2,
    this.target,
    this.height = 170,
    this.valueLabel,
  }) : color = color ?? AppColors.primary,
       color2 = color2 ?? AppColors.slate600;

  final List<BarDatum> data;
  final Color color;
  final Color color2;
  final double? target;
  final double height;

  /// Formats the value printed above the highlighted bar.
  final String Function(double v)? valueLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutBack,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _BarsPainter(data, color, color2, target, t, valueLabel),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  /// Palette version at construction — forces a repaint on theme change.
  final int _paletteVersion = AppColors.version;

  _BarsPainter(this.data, this.color, this.color2, this.target, this.t, this.valueLabel);
  final List<BarDatum> data;
  final Color color;
  final Color color2;
  final double? target;
  final double t;
  final String Function(double v)? valueLabel;

  static const double _labelH = 22;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final twin = data.any((d) => d.value2 != null);
    var maxV = data
        .map((d) => d.value > (d.value2 ?? 0) ? d.value : (d.value2 ?? 0))
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (target != null && target! > maxV) maxV = target!;
    if (maxV <= 0) maxV = 1;

    final chartH = size.height - _labelH - 14;
    final slot = size.width / data.length;
    final barW = twin ? slot * 0.28 : slot * 0.46;
    final depth = barW * 0.38;
    final floor = size.height - _labelH;

    // Floor line.
    canvas.drawLine(
      Offset(0, floor + 0.5),
      Offset(size.width, floor + 0.5),
      Paint()
        ..color = AppColors.divider
        ..strokeWidth = 1,
    );

    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      // Staggered growth.
      final local = ((t * 1.3) - i * 0.05).clamp(0.0, 1.0);
      final cx = slot * i + slot / 2;
      if (twin) {
        _block(canvas, cx - barW - 1, floor, barW, depth, d.value / maxV * chartH * local, color);
        _block(canvas, cx + 1, floor, barW, depth, (d.value2 ?? 0) / maxV * chartH * local, color2);
      } else {
        _block(
          canvas,
          cx - barW / 2,
          floor,
          barW,
          depth,
          d.value / maxV * chartH * local,
          d.highlight ? color : color.withValues(alpha: 0.72),
        );
      }

      final tp = TextPainter(
        text: TextSpan(
          text: d.label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: d.highlight ? FontWeight.w700 : FontWeight.w500,
            color: d.highlight ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, floor + 6));

      if (d.highlight && valueLabel != null && local > 0.95) {
        final vp = TextPainter(
          text: TextSpan(
            text: valueLabel!(d.value),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final top = floor - d.value / maxV * chartH - depth * 0.6 - vp.height - 4;
        vp.paint(canvas, Offset(cx - vp.width / 2, top.clamp(0.0, floor)));
      }
    }

    if (target != null) {
      final y = floor - target! / maxV * chartH;
      final paint = Paint()
        ..color = AppColors.danger.withValues(alpha: 0.7)
        ..strokeWidth = 1.4;
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
      }
    }
  }

  /// Draws one isometric block whose front face spans [x, x+w] × [floor-h, floor].
  void _block(Canvas canvas, double x, double floor, double w, double depth, double h, Color c) {
    if (h <= 0.5) return;
    final top = floor - h;
    final dx = depth * 0.8, dy = depth * 0.5;

    // Contact shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, floor - 3, w + dx, 6), const Radius.circular(3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Side face (right).
    final side = Path()
      ..moveTo(x + w, top)
      ..lineTo(x + w + dx, top - dy)
      ..lineTo(x + w + dx, floor - dy)
      ..lineTo(x + w, floor)
      ..close();
    canvas.drawPath(side, Paint()..color = Color.lerp(c, Colors.black, 0.30)!);

    // Top face.
    final cap = Path()
      ..moveTo(x, top)
      ..lineTo(x + dx, top - dy)
      ..lineTo(x + w + dx, top - dy)
      ..lineTo(x + w, top)
      ..close();
    canvas.drawPath(cap, Paint()..color = Color.lerp(c, Colors.white, 0.35)!);

    // Front face with vertical gradient.
    final front = Rect.fromLTRB(x, top, x + w, floor);
    canvas.drawRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(c, Colors.white, 0.12)!, c, Color.lerp(c, Colors.black, 0.10)!],
        ).createShader(front),
    );
    // Specular stripe.
    canvas.drawRect(
      Rect.fromLTWH(x + w * 0.18, top + 2, w * 0.12, (h - 4).clamp(0, double.infinity)),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old._paletteVersion != _paletteVersion || old.t != t || old.data != data || old.target != target;
}
