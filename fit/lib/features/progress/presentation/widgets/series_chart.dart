import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_colors.dart';

/// Time-series chart for the Progress screen. Handles gaps (null days),
/// bars or a glowing line with a gradient volume, an optional dashed goal
/// line and an optional second line (e.g. weight trend). Tap/drag to
/// inspect a day.
class SeriesChart extends StatefulWidget {
  SeriesChart({
    super.key,
    required this.dates,
    required this.values,
    this.secondary,
    this.bars = false,
    this.target,
    this.decimals = 0,
    this.unit = '',
    this.height = 170,
    Color? color,
  }) : color = color ?? AppColors.primary;

  final List<DateTime> dates;
  final List<double?> values;
  final List<double?>? secondary;
  final bool bars;
  final double? target;
  final int decimals;
  final String unit;
  final double height;
  final Color color;

  @override
  State<SeriesChart> createState() => _SeriesChartState();
}

class _SeriesChartState extends State<SeriesChart> {
  int? _selected;

  void _pick(Offset local, double width) {
    final n = widget.values.length;
    if (n == 0) return;
    final w = width - _SeriesPainter.left - 8;
    final i = (((local.dx - _SeriesPainter.left) / w) * (n - 1)).round().clamp(0, n - 1);
    if (i != _selected) setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    final v = sel == null ? null : widget.values[sel] ?? widget.secondary?[sel];
    final label = sel == null
        ? null
        : '${DateFormat('EEE d MMM').format(widget.dates[sel])}  ·  '
              '${v == null ? 'no data' : '${v.toStringAsFixed(widget.decimals)} ${widget.unit}'.trim()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedOpacity(
          opacity: label == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label ?? ' ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.color),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, box) => GestureDetector(
            onTapDown: (d) => _pick(d.localPosition, box.maxWidth),
            onHorizontalDragUpdate: (d) => _pick(d.localPosition, box.maxWidth),
            onHorizontalDragEnd: (_) => setState(() => _selected = null),
            onTapUp: (_) => Future.delayed(
              const Duration(seconds: 2),
              () => mounted ? setState(() => _selected = null) : null,
            ),
            child: SizedBox(
              height: widget.height,
              width: box.maxWidth,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(Object.hashAll(widget.values)),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  painter: _SeriesPainter(
                    dates: widget.dates,
                    values: widget.values,
                    secondary: widget.secondary,
                    bars: widget.bars,
                    target: widget.target,
                    decimals: widget.decimals,
                    color: widget.color,
                    t: t,
                    selected: _selected,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.dates,
    required this.values,
    required this.secondary,
    required this.bars,
    required this.target,
    required this.decimals,
    required this.color,
    required this.t,
    required this.selected,
  });

  static const double left = 40, bottom = 18, top = 6;

  /// Palette version at construction — forces a repaint on theme change.
  final int _paletteVersion = AppColors.version;
  final List<DateTime> dates;
  final List<double?> values;
  final List<double?>? secondary;
  final bool bars;
  final double? target;
  final int decimals;
  final Color color;
  final double t;
  final int? selected;

  TextPainter _text(String s, {Color? color}) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: 10, color: color ?? AppColors.textMuted, fontFamily: 'Poppins'),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    final all = [...values.whereType<double>(), ...?secondary?.whereType<double>(), ?target];
    if (n == 0 || all.isEmpty) return;
    var lo = all.reduce(min), hi = all.reduce(max);
    if (bars) {
      lo = min(0, lo);
      hi = max(0, hi);
    } else {
      final pad = (hi - lo) * 0.12;
      lo -= pad == 0 ? max(1, hi.abs() * 0.1) : pad;
      hi += pad == 0 ? max(1, hi.abs() * 0.1) : pad;
    }
    if (hi == lo) hi = lo + 1;
    final w = size.width - left - 8, h = size.height - top - bottom;
    double xOf(int i) => left + (n == 1 ? w / 2 : i / (n - 1) * w);
    double yOf(double v) => top + (1 - (v - lo) / (hi - lo)) * h;

    // Grid + y labels.
    final grid = Paint()..color = AppColors.divider;
    for (var k = 0; k <= 3; k++) {
      final v = lo + (hi - lo) * k / 3;
      final y = yOf(v);
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      final tp = _text(_compact(v));
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }

    // X labels: first, middle, last.
    final fmt = DateFormat(n > 120 ? 'MMM' : 'd MMM');
    for (final i in {0, n ~/ 2, n - 1}) {
      final tp = _text(fmt.format(dates[i]));
      final x = (xOf(i) - tp.width / 2).clamp(left, size.width - tp.width);
      tp.paint(canvas, Offset(x, size.height - tp.height));
    }

    // Goal line (dashed).
    if (target != null) {
      final y = yOf(target!);
      final p = Paint()
        ..color = AppColors.success.withValues(alpha: 0.8)
        ..strokeWidth = 1.4;
      for (var x = left; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(min(x + 4, size.width), y), p);
      }
    }

    // Selected day marker.
    if (selected != null) {
      final x = xOf(selected!);
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + h),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      );
    }

    if (bars) {
      final bw = max(1.5, min(14.0, w / n * 0.62));
      final zero = yOf(0);
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) continue;
        final y = zero + (yOf(v) - zero) * t;
        final rect = Rect.fromLTRB(xOf(i) - bw / 2, min(y, zero), xOf(i) + bw / 2, max(y, zero));
        final c = v < 0 ? AppColors.burn : color;
        final shaded = i == selected ? c : c.withValues(alpha: selected == null ? 1 : 0.55);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(min(bw / 2, 4))),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(shaded, Colors.white, 0.25)!, shaded],
            ).createShader(rect),
        );
      }
    } else {
      // Raw points as beads when a secondary trend exists; otherwise a line.
      final primaryIsDots = secondary != null;
      if (!primaryIsDots) _line(canvas, values, xOf, yOf, top + h, color, 3, fill: true);
      if (secondary != null) _line(canvas, secondary!, xOf, yOf, top + h, color, 3, fill: true);
      final dot = n <= 60 || primaryIsDots;
      if (dot) {
        for (var i = 0; i < n; i++) {
          final v = values[i];
          if (v == null || i / max(1, n - 1) > t) continue;
          final o = Offset(xOf(i), yOf(v));
          final r = primaryIsDots ? 3.2 : 2.6;
          canvas.drawCircle(
            o + const Offset(0, 1.2),
            r,
            Paint()..color = Colors.black.withValues(alpha: 0.15),
          );
          canvas.drawCircle(o, r, Paint()..color = primaryIsDots ? color.withValues(alpha: 0.55) : color);
          canvas.drawCircle(
            o - Offset(r * 0.3, r * 0.3),
            r * 0.35,
            Paint()..color = Colors.white.withValues(alpha: 0.7),
          );
        }
      }
    }
  }

  /// Draws [v] as connected segments (gaps stay gaps unless short).
  void _line(
    Canvas canvas,
    List<double?> v,
    double Function(int) xOf,
    double Function(double) yOf,
    double base,
    Color c,
    double width, {
    bool fill = false,
  }) {
    final pts = <Offset>[];
    final cut = (v.length * t).ceil();
    for (var i = 0; i < min(cut, v.length); i++) {
      if (v[i] != null) pts.add(Offset(xOf(i), yOf(v[i]!)));
    }
    if (pts.isEmpty) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    if (fill && pts.length > 1) {
      final area = Path.from(path)
        ..lineTo(pts.last.dx, base)
        ..lineTo(pts.first.dx, base)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0)],
          ).createShader(Rect.fromLTRB(0, 0, 1, base)),
      );
    }
    // Shadow, then line.
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = c.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    if (pts.length == 1) canvas.drawCircle(pts.first, 3, Paint()..color = c);
  }

  String _compact(double v) {
    final a = v.abs();
    if (a >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (a >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (a < 10 && decimals > 0) return v.toStringAsFixed(min(decimals, 2));
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(_SeriesPainter old) =>
      old.t != t ||
      old.selected != selected ||
      old.values != values ||
      old.color != color ||
      old._paletteVersion != _paletteVersion;
}
