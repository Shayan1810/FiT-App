import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../domain/entities/daily_briefing.dart';

/// Icon for an insight category.
IconData insightIcon(InsightCategory c) => switch (c) {
  InsightCategory.sleep => Icons.nightlight_round,
  InsightCategory.nutrition => Icons.restaurant_rounded,
  InsightCategory.training => Icons.fitness_center_rounded,
  InsightCategory.activity => Icons.directions_walk_rounded,
  InsightCategory.body => Icons.monitor_weight_rounded,
  InsightCategory.hydration => Icons.water_drop_rounded,
  InsightCategory.plan => Icons.flag_rounded,
};

/// Colour for an insight tone.
Color insightColor(InsightTone t) => switch (t) {
  InsightTone.positive => AppColors.success,
  InsightTone.info => AppColors.info,
  InsightTone.warning => AppColors.warning,
  InsightTone.alert => AppColors.danger,
};

/// A coach insight card. Tap to reveal the science ("Why?") and citation.
class InsightTile extends StatefulWidget {
  const InsightTile({super.key, required this.insight, this.initiallyOpen = false});
  final Insight insight;
  final bool initiallyOpen;

  @override
  State<InsightTile> createState() => _InsightTileState();
}

class _InsightTileState extends State<InsightTile> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final i = widget.insight;
    final color = insightColor(i.tone);
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.soft(depth: _open ? 0.8 : 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: color)),
              Padding(padding: const EdgeInsets.fromLTRB(18, 16, 16, 16), child: _content(i, color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(Insight i, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(insightIcon(i.category), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    i.message,
                    style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 260),
              child: Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
            ),
          ],
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 260),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHY — THE SCIENCE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(i.why, style: const TextStyle(fontSize: 13, height: 1.45)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        i.reference,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
