import 'package:flutter/material.dart';
import '../../models/meal_data.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';

class MealCard extends StatelessWidget {
  final String title;
  final MealData mealData;
  final VoidCallback onAddFood;
  final VoidCallback onAddRecipe;
  final VoidCallback onAddNote;
  final void Function(int itemIndex, int newQuantity) onEditQuantity;
  final void Function(int itemIndex) onRemove;
  

  const MealCard({
    Key? key,
    required this.title,
    required this.mealData,
    required this.onAddFood,
    required this.onAddRecipe,
    required this.onAddNote,
    required this.onEditQuantity,
    required this.onRemove,
  }) : super(key: key);

  
  Future<void> _showQuantityDialog(
    BuildContext context, int index) async {
    final item = mealData.items[index];
    final unit = (item as dynamic).unit ?? '';
    int initialQty = mealData.quantities[index];
    final qtyCtrl = TextEditingController(text: initialQty.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState2) {
            // Update macros whenever qtyCtrl changes
            qtyCtrl.addListener(() => setState2(() {}));

            // Compute macros for current quantity
            final n = int.tryParse(qtyCtrl.text) ?? initialQty;
            final isRecipe = item is Recipe;
            final baseP = isRecipe
                ? (item as Recipe).totalProtein
                : (item as FoodItem).protein;
            final baseC = isRecipe
                ? (item as Recipe).totalCarbohydrate
                : (item as FoodItem).carbohydrate;
            final baseF = isRecipe
                ? (item as Recipe).totalFat
                : (item as FoodItem).fat;
            final baseCal = isRecipe
                ? (item as Recipe).totalCalories
                : (item as FoodItem).calories;
            final p = baseP * n;
            final c = baseC * n;
            final f = baseF * n;
            final cal = baseCal * n;

            return AlertDialog(
              title: Text('Enter Quantity'),
              contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              insetPadding: EdgeInsets.symmetric(horizontal: 40),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quantity + Unit row
                  Row(children: [
                    // Quantity input
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.straighten,
                              color: Color(0xFF8B7CF6)),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Unit display (black outline, centered text)
                    Expanded(
                      child: TextField(
                        controller:
                            TextEditingController(text: unit),
                        enabled: true,
                        keyboardType: TextInputType.none,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Colors.black, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  SizedBox(height: 16),
                  // Macros display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _mini('P', p, Colors.blue),
                      _mini('C', c, Colors.orange),
                      _mini('F', f, Colors.purple),
                      _mini('Cal', cal, Colors.red),
                    ],
                  ),
                ],
              ),
              actionsPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: Text('Cancel',
                      style: TextStyle(color: Color(0xFF8B7CF6))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newQ =
                        int.tryParse(qtyCtrl.text) ?? initialQty;
                    Navigator.pop(ctx2, newQ);
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      onEditQuantity(index, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = mealData.items;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(children: [
                  _mini('P', mealData.totalProtein, Colors.blue),
                  _mini('C', mealData.totalCarb, Colors.orange),
                  _mini('F', mealData.totalFat, Colors.purple),
                  _mini('Cal', mealData.totalCalories, Colors.red),
                ]),
              ],
            ),
            SizedBox(height: 8),
            // Notes row
            Row(children: [
              Icon(Icons.note, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onAddNote,
                  child: Text(
                    mealData.note?.isNotEmpty == true
                        ? mealData.note!
                        : 'Add notes',
                    style: TextStyle(
                      color: mealData.note?.isNotEmpty == true
                          ? Colors.black
                          : Colors.grey,
                      fontStyle: mealData.note?.isNotEmpty == true
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ]),
            SizedBox(height: 12),
            // Add buttons
            Row(children: [
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Add Food'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100),
                onPressed: onAddFood,
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.menu_book),
                label: Text('Add Recipe'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade100),
                onPressed: onAddRecipe,
              ),
            ]),
            SizedBox(height: 12),
            // Item list
            ...List.generate(items.length, (i) {
              final item = items[i];
              final name = (item as dynamic).name;
              final tag  = (item as dynamic).tag;
              final qty = mealData.quantities.length > i
                ? mealData.quantities[i]
                : 1;
            final unit = item is FoodItem
                ? item.unit
                : item is Recipe
                    ? item.unit
                    : '';

              return Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(Icons.restaurant,
                      size: 18, color: Colors.grey.shade600),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$name ($tag) • $qty x $unit',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.grey.shade700),
                    onPressed: () => _showQuantityDialog(context, i),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => onRemove(i),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, double value, Color color) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '$label:${value.toStringAsFixed(label == 'Cal' ? 0 : 1)}',
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      );
}