import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_log_entry.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../bloc/food_search_cubit.dart';
import '../bloc/nutrition_bloc.dart';
import '../pages/my_foods_page.dart';

/// Search a food and log it into [slot].
Future<void> showAddFoodSheet(BuildContext context, MealSlot slot) async {
  final bloc = context.read<NutritionBloc>();
  final picked = await showFoodPicker(context, actionLabel: 'Add to ${slot.label}');
  if (picked != null) bloc.add(NutritionFoodLogged(picked.$1, picked.$2, slot));
}

/// Opens the food picker; returns the chosen food and grams, or null.
Future<(FoodItem, double)?> showFoodPicker(BuildContext context, {String actionLabel = 'Add'}) {
  return showModalBottomSheet<(FoodItem, double)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) => FoodSearchCubit(sl<NutritionRepository>()),
      child: FractionallySizedBox(heightFactor: 0.92, child: _FoodPicker(actionLabel: actionLabel)),
    ),
  );
}

class _FoodPicker extends StatefulWidget {
  const _FoodPicker({required this.actionLabel});
  final String actionLabel;

  @override
  State<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<_FoodPicker> {
  FoodItem? _selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, a) => SlideTransition(
        position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(a),
        child: FadeTransition(opacity: a, child: child),
      ),
      child: _selected == null
          ? _SearchStep(key: const ValueKey('search'), onPick: (f) => setState(() => _selected = f))
          : AmountStep(
              key: ValueKey(_selected!.id),
              food: _selected!,
              actionLabel: widget.actionLabel,
              onBack: () => setState(() => _selected = null),
              onDone: (g) => Navigator.pop(context, (_selected!, g)),
            ),
    );
  }
}

class _SearchStep extends StatelessWidget {
  const _SearchStep({super.key, required this.onPick});
  final ValueChanged<FoodItem> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              autofocus: true,
              onChanged: context.read<FoodSearchCubit>().search,
              decoration: const InputDecoration(
                hintText: 'Search your foods & recipes',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<FoodSearchCubit, List<FoodItem>>(
              builder: (context, foods) {
                if (foods.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No match',
                    message: 'Try another spelling, or create it as your own food.',
                    action: FilledButton.tonal(
                      onPressed: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => const CustomFoodEditorPage())),
                      child: const Text('Create custom food'),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: foods.length + 1,
                  itemBuilder: (context, i) {
                    if (i == foods.length) {
                      return TextButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const CustomFoodEditorPage())),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text("Can't find it? Create a custom food"),
                      );
                    }
                    final f = foods[i];
                    final s = f.perServing;
                    return ListTile(
                      onTap: () => onPick(f),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(
                          switch (f.origin) {
                            FoodOrigin.custom => Icons.star_rounded,
                            FoodOrigin.recipe => Icons.menu_book_rounded,
                          },
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        '${f.servingLabel} · ${fmtInt(f.servingGrams)} g · P ${s.protein.round()} C ${s.carbs.round()} F ${s.fat.round()}',
                        style: AppText.caption,
                      ),
                      trailing: Text(
                        '${fmtInt(s.kcal)} kcal',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Choose how much of [food]: serving multiples or exact grams.
class AmountStep extends StatefulWidget {
  const AmountStep({
    super.key,
    required this.food,
    required this.actionLabel,
    required this.onDone,
    this.onBack,
    this.initialGrams,
  });

  final FoodItem food;
  final String actionLabel;
  final ValueChanged<double> onDone;
  final VoidCallback? onBack;
  final double? initialGrams;

  @override
  State<AmountStep> createState() => _AmountStepState();
}

class _AmountStepState extends State<AmountStep> {
  late double _grams = widget.initialGrams ?? widget.food.servingGrams;
  late final _ctrl = TextEditingController(text: fmtInt(_grams).replaceAll(',', ''));

  void _set(double g) {
    setState(() => _grams = g);
    _ctrl.text = g.round().toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.food.factsFor(_grams);
    const multiples = [0.5, 1.0, 1.5, 2.0, 3.0];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: [
              if (widget.onBack != null)
                IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(child: Text(widget.food.name, style: AppText.title)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in multiples)
                ChoiceChip(
                  label: Text('${m == m.roundToDouble() ? m.toInt() : m} × ${widget.food.servingLabel}'),
                  selected: (_grams - widget.food.servingGrams * m).abs() < 0.5,
                  onSelected: (_) => _set(widget.food.servingGrams * m),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', suffixText: 'g / ml'),
            onChanged: (v) {
              final g = double.tryParse(v.replaceAll(',', '.'));
              if (g != null && g >= 0) setState(() => _grams = g);
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Fact('kcal', f.kcal, AppColors.primary),
                _Fact('protein', f.protein, AppColors.protein),
                _Fact('carbs', f.carbs, AppColors.carbs),
                _Fact('fat', f.fat, AppColors.fat),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _grams > 0 ? () => widget.onDone(_grams) : null,
            child: Text(widget.actionLabel),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        fmtInt(value),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color),
      ),
      Text(label, style: AppText.caption),
    ],
  );
}
