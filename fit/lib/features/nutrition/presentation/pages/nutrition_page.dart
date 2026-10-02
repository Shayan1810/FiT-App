import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/depth_card.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/ring_3d.dart';
import '../../../insights/presentation/bloc/insights_bloc.dart';
import '../../domain/entities/food_log_entry.dart';
import '../../domain/entities/nutrition_facts.dart';
import '../bloc/nutrition_bloc.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/analysis_sheet.dart';
import '../widgets/edit_entry_sheet.dart';
import 'my_foods_page.dart';

/// The Food tab: day picker, macro rings, "describe your meal", meal slots
/// and water.
class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NutritionBloc, NutritionState>(
      builder: (context, s) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: PageHeader(
                  title: 'Food',
                  subtitle: DateKeys.friendly(s.day),
                  trailing: IconButton.filledTonal(
                    tooltip: 'My foods & recipes',
                    icon: const Icon(Icons.menu_book_rounded),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyFoodsPage())),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              sliver: SliverToBoxAdapter(
                child: DayStrip(
                  selected: s.day,
                  onSelect: (d) => context.read<NutritionBloc>().add(NutritionDaySelected(d)),
                ),
              ),
            ),
            SliverList.list(
              children: [
                Entrance(child: _SummaryCard(totals: s.totals)),
                const Entrance(index: 1, child: _DescribeMeal()),
                if (s.pendingJobs > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${s.pendingJobs} meal(s) will be analysed automatically when you are back online.',
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final (i, slot) in MealSlot.values.indexed)
                  Entrance(
                    index: 2 + i,
                    child: _MealSection(slot: slot, entries: s.slot(slot)),
                  ),
                Entrance(index: 6, child: _WaterCard(ml: s.waterMl)),
                const SizedBox(height: 120),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals});
  final NutritionFacts totals;

  @override
  Widget build(BuildContext context) {
    final targets = context.select((InsightsBloc b) => b.state.briefing?.today.targets);
    if (targets == null) return const SizedBox(height: 12);
    final left = targets.kcal - totals.kcal;
    final rows = [
      ('Calories', totals.kcal, targets.kcal, 'kcal', AppColors.primary),
      ('Protein', totals.protein, targets.protein, 'g', AppColors.protein),
      ('Carbs', totals.carbs, targets.carbs, 'g', AppColors.carbs),
      ('Fat', totals.fat, targets.fat, 'g', AppColors.fat),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: DepthCard(
        tilt: true,
        child: Row(
          children: [
            Ring3D(
              size: 160,
              stroke: 10,
              gap: 3,
              rings: [for (final r in rows) RingSpec(progress: r.$3 <= 0 ? 0 : r.$2 / r.$3, color: r.$5)],
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fmtInt(left.abs()), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  Text(
                    left >= 0 ? 'kcal left' : 'kcal over',
                    style: TextStyle(
                      fontSize: 10,
                      color: left >= 0 ? AppColors.textSecondary : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: r.$5, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 13))),
                          Text(
                            '${fmtInt(r.$2)}/${fmtInt(r.$3)}${r.$4 == 'g' ? 'g' : ''}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Describe what you ate" — the fastest way to log.
class _DescribeMeal extends StatefulWidget {
  const _DescribeMeal();

  @override
  State<_DescribeMeal> createState() => _DescribeMealState();
}

class _DescribeMealState extends State<_DescribeMeal> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    final logged = await showAnalysisSheet(context, t);
    if (logged == true) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadows.soft(depth: 0.6),
          border: Border.all(color: AppColors.primarySoft, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _go(),
                decoration: const InputDecoration(
                  hintText: 'Describe your meal… "2 roti, dal and curd"',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            PressableScale(
              onTap: _go,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.glow(),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _slotIcon(MealSlot s) => switch (s) {
  MealSlot.breakfast => Icons.free_breakfast_rounded,
  MealSlot.lunch => Icons.lunch_dining_rounded,
  MealSlot.dinner => Icons.dinner_dining_rounded,
  MealSlot.snacks => Icons.cookie_rounded,
};

class _MealSection extends StatelessWidget {
  const _MealSection({required this.slot, required this.entries});
  final MealSlot slot;
  final List<FoodLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final kcal = entries.fold<double>(0, (a, e) => a + e.facts.kcal);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                IconBadge(icon: _slotIcon(slot), color: AppColors.primary, onDark: false, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.label, style: AppText.subtitle),
                      Text(
                        entries.isEmpty ? 'Nothing yet' : '${fmtInt(kcal)} kcal · ${entries.length} item(s)',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Add to ${slot.label}',
                  onPressed: () => showAddFoodSheet(context, slot),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            for (final e in entries) _EntryTile(entry: e),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final FoodLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final f = entry.facts;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      onDismissed: (_) {
        final bloc = context.read<NutritionBloc>()..add(NutritionEntryDeleted(entry));
        showToast(
          context,
          'Removed ${entry.name}',
          action: SnackBarAction(label: 'Undo', onPressed: () => bloc.add(NutritionEntryRestored(entry))),
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 4, right: 8),
        onTap: entry.isPending ? null : () => showEditEntrySheet(context, entry),
        title: Text(
          entry.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: entry.isPending
            ? Row(
                children: [
                  SizedBox.square(dimension: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  SizedBox(width: 6),
                  Text('Analysing when online…', style: AppText.caption),
                ],
              )
            : Text(
                '${fmtInt(entry.grams)} g · P ${f.protein.round()} · C ${f.carbs.round()} · F ${f.fat.round()}',
                style: AppText.caption,
              ),
        trailing: Text(
          entry.isPending ? '—' : '${fmtInt(f.kcal)} kcal',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.ml});
  final int ml;

  @override
  Widget build(BuildContext context) {
    final target = context.select((InsightsBloc b) => b.state.briefing?.today.targets.waterMl) ?? 2500;
    final glasses = (target / 250).ceil().clamp(4, 16);
    final filled = (ml / 250).floor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.water_drop_rounded,
                  color: AppColors.water,
                  onDark: false,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Water', style: AppText.subtitle),
                      Text(
                        '${(ml / 1000).toStringAsFixed(2)} of ${(target / 1000).toStringAsFixed(1)} L',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: ml <= 0
                      ? null
                      : () => context.read<NutritionBloc>().add(const NutritionWaterAdded(-250)),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                IconButton(
                  onPressed: () => context.read<NutritionBloc>().add(const NutritionWaterAdded(250)),
                  icon: const Icon(Icons.add_circle_rounded, color: AppColors.water),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < glasses; i++)
                  GestureDetector(
                    onTap: () => context.read<NutritionBloc>().add(NutritionWaterAdded((i + 1) * 250 - ml)),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200 + i * 30),
                      width: 26,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                          top: Radius.circular(3),
                        ),
                        gradient: i < filled
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF67E8F9), AppColors.water],
                              )
                            : null,
                        color: i < filled ? null : AppColors.water.withValues(alpha: 0.10),
                        boxShadow: i < filled ? AppShadows.chip(AppColors.water) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
