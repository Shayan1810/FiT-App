import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/hive_service.dart';
import '../../models/food_item.dart';

class FoodBox extends StatefulWidget {
  final String dateKey;
  final int mealIndex;

  const FoodBox({
    Key? key,
    required this.dateKey,
    required this.mealIndex,
  }) : super(key: key);

  @override
  _FoodBoxState createState() => _FoodBoxState();
}

class _FoodBoxState extends State<FoodBox> {
  late Box<FoodItem> _foodBox;
  List<FoodItem> _allItems = [];
  List<FoodItem> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  bool _searchByTag = false;

  @override
  void initState() {
    super.initState();
    _foodBox = Hive.box<FoodItem>(HiveService.foodItemBoxName);
    _loadItems();
    _searchController.addListener(_filterItems);
  }

  void _loadItems() {
    final items = _foodBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _allItems = items;
      _filteredItems = List.from(items);
    });
  }

  void _filterItems() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = List.from(_allItems);
      } else {
        _filteredItems = _allItems.where((item) {
          final field = _searchByTag ? item.tag : item.name;
          return field.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _showQuantityDialog(FoodItem item) async {
    final unit = item.unit;
    final qtyController = TextEditingController(text: '1');

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState2) => AlertDialog(
          title: Text('Enter Quantity'),
          content: Row(
            children: [
              // Quantity field
              Expanded(
                child: TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.straighten, color: Color(0xFF8B7CF6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  enabled: true,
                  keyboardType: TextInputType.none,
                  decoration: InputDecoration(
                    hintText: unit,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final n = int.tryParse(qtyController.text) ?? 1;
                Navigator.pop(ctx2, n);
              },
              child: Text('OK'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      Navigator.pop(context, {
        'item': item,
        'quantity': result,
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Purple header behind the title
      appBar: AppBar(
        backgroundColor: Color(0xFF8B7CF6),
        title: Text('Add Food'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by ${_searchByTag ? "tag" : "name"}',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                      _searchByTag ? Icons.label : Icons.text_fields),
                  onPressed: () {
                    setState(() {
                      _searchByTag = !_searchByTag;
                      _filterItems();
                    });
                  },
                  tooltip:
                      'Search by ${_searchByTag ? "tag" : "name"}',
                ),
              ],
            ),
          ),

          // Grid of food cards
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3 / 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _filteredItems.length,
                itemBuilder: (context, i) {
                  final f = _filteredItems[i];
                  return GestureDetector(
                    onTap: () => _showQuantityDialog(f),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(f.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text(f.tag,
                                style: TextStyle(
                                    color: Colors.grey)),
                            Spacer(),
                            Text(
                                'P:${f.protein}g  C:${f.carbohydrate}g',
                                style:
                                    TextStyle(fontSize: 12)),
                            Text(
                                'F:${f.fat}g  Cal:${f.calories.toStringAsFixed(0)}',
                                style:
                                    TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
