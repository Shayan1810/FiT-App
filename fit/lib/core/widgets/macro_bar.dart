import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// "Protein 82 / 140 g" row with a recessed groove and a glossy, raised
/// fill that animates to its value (original MacroCard row, upgraded).
class MacroBar extends StatelessWidget {
  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.color,
    this.unit = 'g',
  });

  final String label;
  final double value;
  final double target;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final frac = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final over = target > 0 && value > target * 1.05;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            Text(
              '${value.round()} / ${target.round()} $unit',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: over ? AppColors.danger : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frac),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, f, _) => Container(
                  width: box.maxWidth * f,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(color, Colors.white, 0.35)!,
                        color,
                        Color.lerp(color, Colors.black, 0.15)!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
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
