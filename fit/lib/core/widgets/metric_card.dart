import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'animated_count.dart';
import 'depth_card.dart';

/// The signature original metric tile, rebuilt: gradient block, raised icon badge,
/// a big rolling number and a label — floating in 3D.
class MetricCard extends StatelessWidget {
  MetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.unit = '',
    this.decimals = 0,
    this.caption,
    this.style = DepthStyle.primary,
    Color? accent,
    this.phase = 0,
    this.onTap,
    this.trailing,
  }) : accent = accent ?? AppColors.primary;

  final IconData icon;
  final double value;
  final String label;
  final String unit;
  final int decimals;
  final String? caption;
  final DepthStyle style;
  final Color accent;
  final double phase;
  final VoidCallback? onTap;

  /// Optional small widget at the top-right (e.g. edit button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final onLight = style == DepthStyle.light;
    final fg = onLight ? AppColors.textPrimary : Colors.white;
    return DepthCard(
      style: style,
      accent: accent,
      tilt: true,
      phase: phase,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: onLight ? accent : Colors.white, onDark: !onLight),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: AnimatedCount(
                  value: value,
                  decimals: decimals,
                  style: AppText.metric.copyWith(
                    color: fg,
                    shadows: onLight ? const [] : AppText.metric.shadows,
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Text(
                    unit,
                    style: TextStyle(color: fg.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          Text(
            label,
            style: TextStyle(color: fg.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
