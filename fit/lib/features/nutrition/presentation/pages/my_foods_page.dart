import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/depth_card.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/nutrition_facts.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../bloc/food_search_cubit.dart';
import '../widgets/add_food_sheet.dart';

/// "My foods" and "My recipes" (the original food-item & recipe pages).
class MyFoodsPage extends StatelessWidget {
  const MyFoodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FoodSearchCubit(sl<NutritionRepository>()),
      child: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('My foods & recipes'),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'My foods'),
                    Tab(text: 'Recipes'),
                  ],
                ),
              ),
              floatingActionButton: GradientFab(
                icon: Icons.add_rounded,
                label: 'New',
                onTap: () {
                  final tab = DefaultTabController.of(context).index;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<FoodSearchCubit>(),
                        child: tab == 0 ? const CustomFoodEditorPage() : const RecipeEditorPage(),
                      ),
                    ),
                  );
                },
              ),
              body: BlocBuilder<FoodSearchCubit, List<FoodItem>>(
                builder: (context, _) {
                  final cubit = context.read<FoodSearchCubit>();
                  final foods = cubit.customFoods();
                  final recipes = cubit.recipes();
                  return TabBarView(
                    children: [
                      foods.isEmpty
                          ? const EmptyState(
                              icon: Icons.star_rounded,
                              title: 'No custom foods yet',
                              message: 'Add packaged foods from their label or family recipes you eat often.',
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                              children: [
                                for (final f in foods)
                                  _ItemCard(
                                    title: f.name,
                                    subtitle:
                                        '${f.servingLabel} (${fmtInt(f.servingGrams)} g) · ${fmtInt(f.perServing.kcal)} kcal',
                                    onDelete: () => cubit.deleteCustomFood(f.id),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BlocProvider.value(
                                          value: cubit,
                                          child: CustomFoodEditorPage(initial: f),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                      recipes.isEmpty
                          ? const EmptyState(
                              icon: Icons.menu_book_rounded,
                              title: 'No recipes yet',
                              message: 'Combine ingredients once; log a serving in one tap forever.',
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                              children: [
                                for (final r in recipes)
                                  _ItemCard(
                                    title: r.name,
                                    subtitle:
                                        '${r.servings} servings · ${fmtInt(r.perServing.kcal)} kcal / serving',
                                    onDelete: () => cubit.deleteRecipe(r.id),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BlocProvider.value(
                                          value: cubit,
                                          child: RecipeEditorPage(initial: r),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.title, required this.subtitle, required this.onDelete, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DepthCard(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        onTap: onTap,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: AppText.caption),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Delete "$title"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) onDelete();
            },
          ),
        ),
      ),
    );
  }
}

/// Create/edit a custom food. Values are entered **per serving** (as on a
/// nutrition label) and stored per 100 g.
class CustomFoodEditorPage extends StatefulWidget {
  const CustomFoodEditorPage({super.key, this.initial});
  final FoodItem? initial;

  @override
  State<CustomFoodEditorPage> createState() => _CustomFoodEditorPageState();
}

class _CustomFoodEditorPageState extends State<CustomFoodEditorPage> {
  late final FoodItem? f = widget.initial;
  late final _name = TextEditingController(text: f?.name ?? '');
  late final _label = TextEditingController(text: f?.servingLabel ?? '1 serving');
  late final _grams = TextEditingController(text: f == null ? '100' : f!.servingGrams.round().toString());
  late final _kcal = TextEditingController(text: f == null ? '' : f!.perServing.kcal.round().toString());
  late final _p = TextEditingController(text: f == null ? '' : f!.perServing.protein.toStringAsFixed(1));
  late final _c = TextEditingController(text: f == null ? '' : f!.perServing.carbs.toStringAsFixed(1));
  late final _fat = TextEditingController(text: f == null ? '' : f!.perServing.fat.toStringAsFixed(1));
  late final _fiber = TextEditingController(text: f == null ? '' : f!.perServing.fiber.toStringAsFixed(1));

  double _v(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final grams = _v(_grams);
    if (_name.text.trim().isEmpty || grams <= 0) {
      showToast(context, 'Name and serving weight are required.');
      return;
    }
    var kcal = _v(_kcal);
    if (kcal == 0) kcal = _v(_p) * 4 + _v(_c) * 4 + _v(_fat) * 9; // Atwater fallback
    final perServing = NutritionFacts(
      kcal: kcal,
      protein: _v(_p),
      carbs: _v(_c),
      fat: _v(_fat),
      fiber: _v(_fiber),
    );
    final food = FoodItem(
      id: f?.id ?? IdGenerator.next('food_'),
      name: _name.text.trim(),
      per100g: perServing.scale(100 / grams),
      servingGrams: grams,
      servingLabel: _label.text.trim().isEmpty ? '1 serving' : _label.text.trim(),
      category: 'My foods',
      origin: FoodOrigin.custom,
    );
    final cubit = context.read<FoodSearchCubit?>();
    if (cubit != null) {
      await cubit.saveCustomFood(food);
    } else {
      await sl<NutritionRepository>().saveCustomFood(food);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget num(TextEditingController c, String label, String suffix) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(f == null ? 'New food' : 'Edit food')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Serving label'),
                ),
              ),
              const SizedBox(width: 12),
              num(_grams, 'Weight', 'g'),
            ],
          ),
          const SizedBox(height: 20),
          Text('Nutrition per serving', style: AppText.subtitle),
          const SizedBox(height: 12),
          Row(children: [num(_kcal, 'Calories', 'kcal'), const SizedBox(width: 12), num(_p, 'Protein', 'g')]),
          const SizedBox(height: 12),
          Row(children: [num(_c, 'Carbs', 'g'), const SizedBox(width: 12), num(_fat, 'Fat', 'g')]),
          const SizedBox(height: 12),
          Row(children: [num(_fiber, 'Fibre', 'g'), const SizedBox(width: 12), const Spacer()]),
          const SizedBox(height: 8),
          Text(
            'Leave calories empty to compute them from macros (4/4/9 kcal per g).',
            style: AppText.caption,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save food')),
        ],
      ),
    );
  }
}

/// Create/edit a recipe from ingredients.
class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key, this.initial});
  final Recipe? initial;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late int _servings = widget.initial?.servings ?? 2;
  late final List<RecipeIngredient> _items = [...?widget.initial?.ingredients];

  Recipe get _recipe => Recipe(
    id: widget.initial?.id ?? IdGenerator.next('recipe_'),
    name: _name.text.trim(),
    servings: _servings,
    ingredients: _items,
  );

  Future<void> _add() async {
    final picked = await showFoodPicker(context, actionLabel: 'Add ingredient');
    if (picked == null) return;
    setState(
      () => _items.add(
        RecipeIngredient(
          name: picked.$1.name,
          grams: picked.$2,
          facts: picked.$1.factsFor(picked.$2),
          foodId: picked.$1.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _recipe;
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'New recipe' : 'Edit recipe')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Recipe name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Servings', style: AppText.subtitle)),
              IconButton(
                onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_servings', style: AppText.title),
              IconButton(
                onPressed: () => setState(() => _servings++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DepthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingredients', style: AppText.subtitle),
                for (final (i, ing) in _items.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ing.name),
                    subtitle: Text(
                      '${fmtInt(ing.grams)} g · ${fmtInt(ing.facts.kcal)} kcal',
                      style: AppText.caption,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _items.removeAt(i)),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add ingredient'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_items.isNotEmpty)
            DepthCard(
              style: DepthStyle.primary,
              child: Text(
                'Per serving: ${fmtInt(r.perServing.kcal)} kcal · P ${r.perServing.protein.round()} g · '
                'C ${r.perServing.carbs.round()} g · F ${r.perServing.fat.round()} g',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _name.text.trim().isEmpty || _items.isEmpty
                ? null
                : () async {
                    await context.read<FoodSearchCubit>().saveRecipe(r);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('Save recipe'),
          ),
        ],
      ),
    );
  }
}
