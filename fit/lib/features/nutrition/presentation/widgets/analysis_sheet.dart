import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/nebula_orb.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../../../core/utils/id_generator.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_log_entry.dart';
import '../../domain/entities/nutrition_analysis.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../bloc/meal_analyzer_cubit.dart';
import '../bloc/nutrition_bloc.dart';
import 'add_food_sheet.dart';

/// Analyses [text] and lets the user log the result. Returns true if logged.
Future<bool?> showAnalysisSheet(BuildContext context, String text) {
  final nutrition = context.read<NutritionBloc>();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: nutrition),
        BlocProvider(create: (_) => MealAnalyzerCubit(sl<NutritionAnalysisRepository>())..analyze(text)),
      ],
      child: const _AnalysisSheet(),
    ),
  );
}

class _AnalysisSheet extends StatefulWidget {
  const _AnalysisSheet();

  @override
  State<_AnalysisSheet> createState() => _AnalysisSheetState();
}

class _AnalysisSheetState extends State<_AnalysisSheet> {
  MealSlot _slot = MealSlotX.forTime(DateTime.now());

  (String, Color, IconData) _sourceInfo(NutritionAnalysis a) => switch (a.source) {
    AnalysisSource.cache => ('From your history (cached)', AppColors.info, Icons.history_rounded),
    AnalysisSource.localDatabase => (
      'From My foods (offline)',
      AppColors.success,
      Icons.offline_bolt_rounded,
    ),
    AnalysisSource.gemini => ('Gemini AI estimate', AppColors.primary, Icons.auto_awesome_rounded),
    AnalysisSource.partial => ('Partly recognised', AppColors.warning, Icons.rule_rounded),
    AnalysisSource.pending => ('Will analyse when online', AppColors.warning, Icons.cloud_off_rounded),
  };

  /// Stores an AI-recognised item as a custom food, so it is understood
  /// offline next time.
  Future<void> _saveToMyFoods(BuildContext context, AnalyzedItem item) async {
    await sl<NutritionRepository>().saveCustomFood(
      FoodItem(
        id: IdGenerator.next('food_'),
        name: item.name,
        per100g: item.facts.scale(100 / item.grams),
        servingGrams: item.grams,
        servingLabel: '1 serving',
        category: 'My foods',
      ),
    );
    if (context.mounted) showToast(context, 'Saved "${item.name}" to My foods');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MealAnalyzerCubit, MealAnalyzerState>(
      builder: (context, s) {
        if (s.status != AnalyzerStatus.done || s.result == null) {
          return const SizedBox(
            height: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NebulaOrb(size: 96, energy: 1),
                SizedBox(height: 8),
                Text('Nebula is reading your meal…'),
              ],
            ),
          );
        }
        final a = s.result!;
        final (label, color, icon) = _sourceInfo(a);
        final canLog = a.items.isNotEmpty || a.source == AnalysisSource.pending;
        final aiOn = context.read<MealAnalyzerCubit>().aiEnabled;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('"${a.query}"', style: AppText.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Pill(label, color: color, icon: icon),
              ),
              const SizedBox(height: 12),
              for (final item in a.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${fmtInt(item.grams)} g · P ${item.facts.protein.round()} · C ${item.facts.carbs.round()} · F ${item.facts.fat.round()}'
                    '${item.confidence < 0.85 ? ' · ~${(item.confidence * 100).round()}% sure' : ''}',
                    style: AppText.caption,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${fmtInt(item.facts.kcal)} kcal',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (item.foodId == null && item.grams > 0)
                        IconButton(
                          tooltip: 'Save to My foods',
                          icon: Icon(Icons.bookmark_add_outlined, color: AppColors.primary, size: 20),
                          onPressed: () => _saveToMyFoods(context, item),
                        ),
                    ],
                  ),
                ),
              if (a.items.isNotEmpty) ...[
                const Divider(),
                Row(
                  children: [
                    Expanded(child: Text('Total', style: AppText.subtitle)),
                    Text(
                      '${fmtInt(a.total.kcal)} kcal · ${a.total.protein.round()} g protein',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
              if (a.source == AnalysisSource.pending)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "You're offline (or the AI is busy). I'll save it now and fill in the numbers automatically once you're back online.",
                    style: AppText.body,
                  ),
                ),
              if (a.unmatched.isNotEmpty && a.source != AnalysisSource.pending) ...[
                const SizedBox(height: 8),
                Text(
                  'Not recognised: ${a.unmatched.join(', ')}',
                  style: const TextStyle(color: AppColors.warning),
                ),
                if (!aiOn)
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Enable AI recognition (optional)'),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final bloc = context.read<NutritionBloc>();
                    final picked = await showFoodPicker(context, actionLabel: 'Add to ${_slot.label}');
                    if (picked != null) {
                      bloc.add(NutritionFoodLogged(picked.$1, picked.$2, _slot));
                      if (a.items.isEmpty) nav.pop(true);
                    }
                  },
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search the missing food'),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in MealSlot.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: _slot == m,
                      onSelected: (_) => setState(() => _slot = m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: canLog
                    ? () {
                        context.read<NutritionBloc>().add(NutritionAnalysisLogged(a, _slot));
                        Navigator.pop(context, true);
                      }
                    : null,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  a.source == AnalysisSource.pending ? 'Save & analyse later' : 'Log to ${_slot.label}',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
