import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A number that rolls smoothly to its new value whenever it changes.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final TextStyle? style;
  final int decimals;
  final String prefix;
  final String suffix;
  final Duration duration;

  static final NumberFormat _int = NumberFormat.decimalPattern();

  /// Formats [v] with thousands separators (or fixed decimals).
  static String format(double v, int decimals) =>
      decimals == 0 ? _int.format(v.round()) : v.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '$prefix${format(v, decimals)}$suffix',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );
  }
}
