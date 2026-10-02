import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_log_entry.dart';
import '../bloc/nutrition_bloc.dart';
import 'add_food_sheet.dart';

/// Change the amount of a logged entry (nutrition rescales proportionally).
Future<void> showEditEntrySheet(BuildContext context, FoodLogEntry entry) {
  final bloc = context.read<NutritionBloc>();
  final grams = entry.grams <= 0 ? 100.0 : entry.grams;
  // Represent the entry as a food whose "serving" is the logged amount.
  final asFood = FoodItem(
    id: entry.foodId ?? entry.id,
    name: entry.name,
    per100g: entry.facts.scale(100 / grams),
    servingGrams: grams,
    servingLabel: 'logged amount',
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AmountStep(
      food: asFood,
      actionLabel: 'Update',
      initialGrams: grams,
      onDone: (g) {
        bloc.add(NutritionEntryAmountChanged(entry, g));
        Navigator.pop(context);
      },
    ),
  );
}
