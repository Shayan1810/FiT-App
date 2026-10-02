import 'package:flutter/material.dart';

/// Staggered "flip-up" entrance: the child rises, fades in and rotates from
/// a slight 3D tilt to flat. Give list items increasing [index] values for a
/// continuous cascading reveal.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0, this.step = 70});
  final Widget child;
  final int index;

  /// Delay between consecutive indices (ms).
  final int step;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index.clamp(0, 12) * widget.step), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..translateByDouble(0, 36 * (1 - t), 0, 1)
              ..rotateX(0.35 * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
