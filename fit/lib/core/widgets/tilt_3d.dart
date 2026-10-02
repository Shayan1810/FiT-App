import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ambient_motion.dart';

/// Makes any widget a living 3D object.
///
/// * **Idle float** — gently rocks on X/Y following [AmbientMotion]
///   (phase-shifted by [phase] so neighbouring cards don't move in sync —
///   the effect from the original cards).
/// * **Touch tilt** — the card leans towards the finger (perspective
///   transform) and springs back on release.
/// * **Press depth** — shrinks slightly while pressed, like a physical key.
///
/// Uses a raw [Listener] for tilt so it never steals scroll gestures.
class Tilt3D extends StatefulWidget {
  const Tilt3D({
    super.key,
    required this.child,
    this.onTap,
    this.maxTilt = 0.12,
    this.idleAmplitude = 0.035,
    this.phase = 0,
    this.float = true,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Maximum touch tilt in radians.
  final double maxTilt;

  /// Idle rocking amplitude in radians.
  final double idleAmplitude;

  /// 0–1 phase offset for the idle animation.
  final double phase;

  /// Disable idle motion (e.g. inside lists).
  final bool float;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  Offset _target = Offset.zero; // −1…1 on each axis
  bool _pressed = false;
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Offset _from = Offset.zero;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _onMove(PointerEvent e) {
    final size = (context.findRenderObject() as RenderBox?)?.size;
    if (size == null || size.isEmpty) return;
    final dx = (e.localPosition.dx / size.width - 0.5) * 2;
    final dy = (e.localPosition.dy / size.height - 0.5) * 2;
    _spring.stop();
    setState(() => _target = Offset(dx.clamp(-1, 1), dy.clamp(-1, 1)));
  }

  void _release() {
    _from = _target;
    _target = Offset.zero;
    _pressed = false;
    _spring.forward(from: 0);
    setState(() {});
  }

  Offset get _current {
    if (!_spring.isAnimating) return _target;
    final t = Curves.elasticOut.transform(_spring.value);
    return Offset.lerp(_from, _target, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final ambient = widget.float ? AmbientMotion.of(context) : kAlwaysCompleteAnimation;
    return Listener(
      onPointerDown: (e) {
        _pressed = true;
        _onMove(e);
      },
      onPointerMove: _onMove,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: GestureDetector(
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onTap!();
              },
        child: AnimatedBuilder(
          animation: Listenable.merge([ambient, _spring]),
          builder: (context, child) {
            final a = (ambient.value + widget.phase) * 2 * math.pi;
            final idle = widget.float ? widget.idleAmplitude : 0.0;
            final c = _current;
            final m = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(idle * math.sin(a) - c.dy * widget.maxTilt)
              ..rotateY(idle * math.cos(a) + c.dx * widget.maxTilt);
            final s = _pressed ? 0.975 : 1.0;
            m.scaleByDouble(s, s, 1, 1);
            return Transform(alignment: Alignment.center, transform: m, child: child);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
