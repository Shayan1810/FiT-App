import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';

class EditQuantityPage extends StatefulWidget {
  final dynamic item;
  final int initialQuantity;

  const EditQuantityPage({
    Key? key,
    required this.item,
    required this.initialQuantity,
  }) : super(key: key);

  @override
  _EditQuantityPageState createState() => _EditQuantityPageState();
}

class _EditQuantityPageState extends State<EditQuantityPage> {
  late TextEditingController _qtyController;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _qtyController =
        TextEditingController(text: widget.initialQuantity.toString())
          ..addListener(() => setState(() {}));
    if (widget.item is FoodItem) {
      _unit = (widget.item as FoodItem).unit;
    } else {
      _unit = (widget.item as Recipe).unit;
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(_qtyController.text) ?? widget.initialQuantity;
    // Base macros
    final baseP = widget.item is FoodItem
        ? (widget.item as FoodItem).protein
        : (widget.item as Recipe).totalProtein;
    final baseC = widget.item is FoodItem
        ? (widget.item as FoodItem).carbohydrate
        : (widget.item as Recipe).totalCarbohydrate;
    final baseF = widget.item is FoodItem
        ? (widget.item as FoodItem).fat
        : (widget.item as Recipe).totalFat;
    final baseCal = widget.item is FoodItem
        ? (widget.item as FoodItem).calories
        : (widget.item as Recipe).totalCalories;
    // Scaled totals
    final p = baseP * n;
    final c = baseC * n;
    final f = baseF * n;
    final cal = baseCal * n;

    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Quantity'),
        backgroundColor: Color(0xFF8B7CF6),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    prefixIcon:
                        Icon(Icons.straighten, color: Color(0xFF8B7CF6)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: _unit),
                  enabled: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          BorderSide(color: Colors.black, width: 1.2),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ]),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _mini('P', p, Colors.blue),
                _mini('C', c, Colors.orange),
                _mini('F', f, Colors.purple),
                _mini('Cal', cal, Colors.red),
              ],
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: Text('Cancel',
                      style: TextStyle(color: Color(0xFF8B7CF6))),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  child: Text('OK'),
                  onPressed: () {
                    final newQty =
                        int.tryParse(_qtyController.text) ??
                        widget.initialQuantity;
                    Navigator.pop(context, newQty);
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, double value, Color color) {
    final txt = label == 'Cal'
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return Column(
      children: [
        Text(txt,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
