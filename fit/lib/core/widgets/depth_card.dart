import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import 'tilt_3d.dart';

/// Visual style of a [DepthCard].
enum DepthStyle { light, primary, dark, accent }

/// The basic elevated surface of FiT: rounded, gradient-filled, with layered
/// 3D shadows and an optional [Tilt3D] wrapper.
class DepthCard extends StatelessWidget {
  DepthCard({
    super.key,
    required this.child,
    this.style = DepthStyle.light,
    Color? accent,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
    this.tilt = false,
    this.phase = 0,
    this.depth = 1,
    this.gradient,
  }) : accent = accent ?? AppColors.primary;

  final Widget child;
  final DepthStyle style;

  /// Colour used by [DepthStyle.accent].
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Wrap in [Tilt3D] (floating + touch tilt).
  final bool tilt;
  final double phase;

  /// Shadow depth multiplier.
  final double depth;

  /// Overrides the style's gradient.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final (Gradient g, List<BoxShadow> shadows) = switch (style) {
      DepthStyle.light => (AppColors.lightGradient, AppShadows.soft(depth: depth)),
      DepthStyle.primary => (AppColors.primaryGradient, AppShadows.colored(AppColors.primary, depth: depth)),
      DepthStyle.dark => (AppColors.slateGradient, AppShadows.dark(depth: depth)),
      DepthStyle.accent => (AppColors.accentGradient(accent), AppShadows.colored(accent, depth: depth)),
    };
    Widget card = Container(
      decoration: BoxDecoration(
        gradient: gradient ?? g,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
        border: style == DepthStyle.light
            ? Border.all(color: AppColors.palette.cardBorder, width: 1.2)
            : Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // Glossy top highlight — sells the "physical surface" look.
            if (style != DepthStyle.light)
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
    if (tilt) return Tilt3D(onTap: onTap, phase: phase, child: card);
    if (onTap != null) return PressableScale(onTap: onTap!, child: card);
    return card;
  }
}

/// Shrinks its child while pressed (physical button feel).
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, required this.onTap, this.scale = 0.96});
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Raised square icon "badge" (original card icon style).
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color = Colors.white,
    this.background,
    this.size = 22,
    this.onDark = true,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  /// True when placed on a coloured/dark card (translucent white tile).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (onDark ? Colors.white.withValues(alpha: 0.22) : color.withValues(alpha: 0.12));
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: onDark ? 0.15 : 0.06),
            blurRadius: 10,
            offset: const Offset(2, 3),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: onDark ? 0.25 : 0.9),
            blurRadius: 5,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}
