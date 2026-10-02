import 'package:flutter/material.dart';

/// One shared, slow, looping animation (0→1 every 6 s) that every floating
/// 3D card listens to. A single ticker for the whole app keeps idle motion
/// smooth and battery-cheap (the original app ran one controller per card).
///
/// Place once above the app shell; read with [AmbientMotion.of].
class AmbientMotion extends StatefulWidget {
  const AmbientMotion({super.key, required this.child});
  final Widget child;

  /// The ambient animation, or a stopped one if none is provided or the
  /// user enabled "Remove animations" in system accessibility settings.
  static Animation<double> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AmbientScope>();
    if (scope == null || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      return kAlwaysCompleteAnimation;
    }
    return scope.animation;
  }

  @override
  State<AmbientMotion> createState() => _AmbientMotionState();
}

class _AmbientMotionState extends State<AmbientMotion> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AmbientScope(animation: _c, child: widget.child);
}

class _AmbientScope extends InheritedWidget {
  const _AmbientScope({required this.animation, required super.child});
  final Animation<double> animation;

  @override
  bool updateShouldNotify(_AmbientScope old) => old.animation != animation;
}
