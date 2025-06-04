import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../models/meal_data.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';
import 'MealCard.dart';
import 'foodbox.dart';
import 'recipebox.dart';
import '../Nutrition/YourFoodItems.dart';
import '../Nutrition/YourRecipe.dart';

class CalorieLog extends StatefulWidget {
  @override
  _CalorieLogState createState() => _CalorieLogState();
}

class _CalorieLogState extends State<CalorieLog> {
  late Box _logBox;
  DateTime selectedDate = DateTime.now();
  late int mealCount;
  late List<int> _mealIndices;

  static const int minMeals = 1;
  static const int maxMeals = 10;

  @override
  void initState() {
    super.initState();
    _logBox = Hive.box('calorieLogBox');
    _initializeForDate(selectedDate);
  }

  void _reloadState() {
    final meals = _meals;
    mealCount = meals.length - 1; // last is Extras
    _mealIndices = [for (int i = 1; i <= mealCount; i++) i, -1];
  }

  String _keyFor(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(d);

  void _initializeForDate(DateTime date) {
    final key = _keyFor(date);
    if (!_logBox.containsKey(key)) {
      final defaultCount = mealCountOrDefault;
      final initial = List<MealData>.generate(
        defaultCount + 1,
        (i) => MealData(
          mealName:
              i < defaultCount ? 'Meal ${i + 1}' : 'Extras',
        ),
      );
      _logBox.put(key, initial);
    }
    _loadCountAndIndices();
  }

  int get mealCountOrDefault => mealCount ?? 3;

  void _loadCountAndIndices() {
    final meals = _meals;
    mealCount = meals.isEmpty ? 3 : meals.length - 1;
    _mealIndices = List<int>.generate(mealCount, (i) => i + 1)
      ..add(-1);
  }

  List<MealData> get _meals {
    final raw = _logBox.get(_keyFor(selectedDate));
    if (raw is List) return raw.cast<MealData>();
    return [];
  }

  void _saveMeals() {
    _logBox.put(_keyFor(selectedDate), _meals);
    _reloadState();
  }

  void _changeDate(int offset) {
    setState(() {
      selectedDate =
          selectedDate.add(Duration(days: offset));
      _initializeForDate(selectedDate);
    });
  }

  void _removeItem(int mealIdx, int itemIdx) {
    setState(() {
      _meals[mealIdx].items.removeAt(itemIdx);
      _meals[mealIdx].quantities.removeAt(itemIdx);
      _saveMeals();
    });
  }

  void _editQuantity(int mealIdx, int itemIdx, int newQty) {
    setState(() {
      _meals[mealIdx].quantities[itemIdx] = newQty;
      _saveMeals();
    });
  }


  String get _displayDate {
    final now = DateTime.now();
    final d1 = DateTime(selectedDate.year,
        selectedDate.month, selectedDate.day);
    final d2 = DateTime(now.year, now.month, now.day);
    final diff = d1.difference(d2).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEE, MMM d, yyyy')
        .format(selectedDate);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _initializeForDate(selectedDate);
      });
    }
  }

  Future<void> _addFood(int idx) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodBox(
          dateKey: _keyFor(selectedDate),
          mealIndex: idx,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _meals[idx].items.add(result['item'] as FoodItem);
        _meals[idx].quantities.add(result['quantity'] as int);
        _saveMeals();
      });
    }
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _ensureDateKey(DateTime date) {
    final key = _key(date);
    if (!_logBox.containsKey(key)) {
      _logBox.put(key, <MealData>[
        for (int i = 1; i <= 3; i++) MealData(mealName: 'Meal $i'),
        MealData(mealName: 'Extras'),
      ]);
    }
    _reloadState();
  }

  Future<void> _addRecipe(int idx) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeBox(
          dateKey: _key(selectedDate),
          mealIndex: idx,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _meals[idx].items.add(result['item'] as Recipe);
        _meals[idx].quantities.add(result['quantity'] as int);
        _saveMeals();
      });
    }
  }

  Future<void> _showNoteDialog(int idx) async {
    final controller =
        TextEditingController(text: _meals[idx].note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 30,
          decoration: InputDecoration(
              hintText: 'Write a note (max 30 words)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text),
              child: Text('Save')),
        ],
      ),
    );
    if (note != null) {
      setState(() {
        _meals[idx].note = note;
        _saveMeals();
      });
    }
  }

  void _showMealCountDialog() {
    int newCount = mealCount;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setD) => AlertDialog(
          title: Text('Select number of meals'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_left),
                onPressed: newCount > minMeals
                    ? () => setD(() => newCount--)
                    : null,
              ),
              SizedBox(
                width: 40,
                child: TextField(
                  controller:
                      TextEditingController(text: '$newCount'),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final n = int.tryParse(val);
                    if (n != null &&
                        n >= minMeals &&
                        n <= maxMeals) {
                      setD(() => newCount = n);
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_right),
                onPressed: newCount < maxMeals
                    ? () => setD(() => newCount++)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _adjustMealCards(newCount);
                });
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _adjustMealCards(int newCount) {
    final diff = newCount - mealCount;
    final meals = _meals;
    final extrasIdx =
        meals.indexWhere((m) => m.mealName == 'Extras');
    if (diff < 0) {
      for (int i = 0; i < -diff; i++) {
        if (extrasIdx - 1 - i >= 0) {
          meals.removeAt(extrasIdx - 1 - i);
        }
      }
    } else if (diff > 0) {
      for (int i = 0; i < diff; i++) {
        final num = mealCount + i + 1;
        meals.insert(
            extrasIdx + i, MealData(mealName: 'Meal $num'));
      }
    }
    mealCount = newCount;
    _saveMeals();
    _loadCountAndIndices();
  }

  void _onMenuSelect(String choice) {
    if (choice == 'father') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => YourFoodItems()));
    } else if (choice == 'mother') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => YourRecipe()));
    } else {
      _showMealCountDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meals = _meals;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF8B7CF6),
        title: Text('Log',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: BackButton(),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: _onMenuSelect,
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'father', child: Text('Father')),
              PopupMenuItem(
                  value: 'mother', child: Text('Mother')),
              PopupMenuItem(
                  value: 'meals', child: Text('Total Meals')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector with tap-to-pick
          Container(
            color: Colors.grey.shade100,
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: Icon(Icons.arrow_left),
                    onPressed: () =>
                        _changeDate(-1)),
                GestureDetector(
                  onTap: _pickDate,
                  child: Text(_displayDate,
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
                        decoration:
                            TextDecoration.underline,
                        color: Colors.blue,
                      )),
                ),
                IconButton(
                    icon: Icon(Icons.arrow_right),
                    onPressed: () =>
                        _changeDate(1)),
              ],
            ),
          ),

          // Daily totals
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 16, horizontal: 12),
            child: Card(
              elevation: 2,
              shape:
                  RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                              12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceAround,
                  children: [
                    _macroBox(
                        'Protein',
                        meals.fold(0,
                            (s, m) => s + m.totalProtein),
                        Colors.blue),
                    _macroBox(
                        'Fat',
                        meals.fold(0,
                            (s, m) => s + m.totalFat),
                        Colors.purple),
                    _macroBox(
                        'Carb',
                        meals.fold(0,
                            (s, m) => s + m.totalCarb),
                        Colors.orange),
                    _macroBox(
                        'Calories',
                        meals.fold(0,
                            (s, m) =>
                                s + m.totalCalories),
                        Colors.red),
                  ],
                ),
              ),
            ),
          ),

          // Meal cards + Extras
          Expanded(
            child: ListView.builder(
              itemCount: _mealIndices.length,
              itemBuilder:
                  (context, index) {
                final mi = _mealIndices[index];
                final title = mi == -1
                    ? 'Extras'
                    : 'Meal $mi';
                final data = mi == -1
                    ? meals.last
                    : meals[mi - 1];
                return MealCard(
                  title: title,
                  mealData: data,
                  onAddFood:    () => _addFood(index),
                  onAddRecipe:  () => _addRecipe(index),
                  onAddNote:    () => _showNoteDialog(index),
                  onRemove:     (itemIdx)       => _removeItem(index, itemIdx),
                  onEditQuantity: (itemIdx, qty) => _editQuantity(index, itemIdx, qty),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroBox(
          String label, double val, Color color) =>
      Column(
        children: [
          Text(val.toStringAsFixed(
              label == 'Calories' ? 0 : 1),
              style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 18,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: color)),
        ],
      );
}