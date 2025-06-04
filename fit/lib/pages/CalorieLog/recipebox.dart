import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/hive_service.dart';
import '../../models/recipe.dart';

class RecipeBox extends StatefulWidget {
  final String dateKey;
  final int mealIndex;

  const RecipeBox({
    Key? key,
    required this.dateKey,
    required this.mealIndex,
  }) : super(key: key);

  @override
  _RecipeBoxState createState() => _RecipeBoxState();
}

class _RecipeBoxState extends State<RecipeBox> {
  late Box<Recipe> _box;
  List<Recipe> _all = [];
  List<Recipe> _filtered = [];
  final TextEditingController _ctrl = TextEditingController();
  bool _searchByTag = false;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<Recipe>(HiveService.recipeBoxName);
    _load();
    _ctrl.addListener(_filter);
  }

  void _load() {
    final list = _box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _all = list;
      _filtered = List.from(list);
    });
  }

  void _filter() {
    final q = _ctrl.text.toLowerCase();
    setState(() {
      if (q.isEmpty)
        _filtered = List.from(_all);
      else
        _filtered = _all.where((r) {
          final field = _searchByTag ? r.tag : r.name;
          return field.toLowerCase().contains(q);
        }).toList();
    });
  }

  Future<void> _showQuantityDialog(Recipe item) async {
    final qtyCtrl = TextEditingController(text: '1');
    final unit = item.unit;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState2) {
          qtyCtrl.addListener(() => setState2(() {}));
          final n = int.tryParse(qtyCtrl.text) ?? 1;
          final p = item.totalProtein * n;
          final c = item.totalCarbohydrate * n;
          final f = item.totalFat * n;
          final cal = item.totalCalories * n;

          return AlertDialog(
            title: Text('Enter Quantity'),
            contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            insetPadding: EdgeInsets.symmetric(horizontal: 40),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      prefixIcon:
                          Icon(Icons.straighten, color: Color(0xFF8B7CF6)),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: unit),
                    enabled: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: Colors.black, width: 1.2),
                      ),
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _mini('P', p, Colors.blue),
                  _mini('C', c, Colors.orange),
                  _mini('F', f, Colors.purple),
                  _mini('Cal', cal, Colors.red),
                ],
              )
            ]),
            actionsPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: Text('Cancel',
                      style: TextStyle(color: Color(0xFF8B7CF6)))),
              ElevatedButton(
                  onPressed: () {
                    final q = int.tryParse(qtyCtrl.text) ?? 1;
                    Navigator.pop(ctx2, q);
                  },
                  child: Text('OK')),
            ],
          );
        },
      ),
    );

    if (result != null) {
      Navigator.pop(context, {'item': item, 'quantity': result});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Recipe'),
        centerTitle: true,
        backgroundColor: Color(0xFF8B7CF6),
      ),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
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
              icon: Icon(_searchByTag ? Icons.label : Icons.text_fields),
              onPressed: () => setState(() {
                _searchByTag = !_searchByTag;
                _filter();
              }),
              tooltip: 'Search by ${_searchByTag ? "tag" : "name"}',
            ),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              itemCount: _filtered.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3 / 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) {
                final r = _filtered[i];
                return GestureDetector(
                  onTap: () => _showQuantityDialog(r),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(r.tag, style: TextStyle(color: Colors.grey)),
                          Spacer(),
                          Text(
                              'P:${r.totalProtein}g  C:${r.totalCarbohydrate}g',
                              style: TextStyle(fontSize: 12)),
                          Text('F:${r.totalFat}g  Cal:${r.totalCalories}',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _mini(String label, double val, Color color) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '$label:${val.toStringAsFixed(label == 'Cal' ? 0 : 1)}',
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      );
}
