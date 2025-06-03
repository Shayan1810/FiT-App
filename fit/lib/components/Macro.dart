import 'package:flutter/material.dart';
import 'dart:math' as math;

class MacroCard extends StatefulWidget {
  final int proteinConsumed;
  final int proteinTotal;
  final int carbConsumed;
  final int carbTotal;
  final int fatConsumed;
  final int fatTotal;
  final AnimationController floatController;

  MacroCard({
    Key? key,
    required this.proteinConsumed,
    required this.proteinTotal,
    required this.carbConsumed,
    required this.carbTotal,
    required this.fatConsumed,
    required this.fatTotal,
    required this.floatController,
  }) : super(key: key);

  @override
  _MacroCardState createState() => _MacroCardState();
}

class _MacroCardState extends State<MacroCard> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.floatController,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(0.02 * math.sin(widget.floatController.value * 2 * math.pi))
            ..translate(0.0, widget.floatController.value * 5),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: Offset(0, 15),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 60,
                  spreadRadius: 0,
                  offset: Offset(0, 30),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(-5, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Macronutrients',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 13),
                _buildMacroRow(
                  'Protein',
                  widget.proteinConsumed,
                  widget.proteinTotal,
                  Colors.blue.shade500,
                ),
                SizedBox(height: 9),
                _buildMacroRow(
                  'Carbohydrate',
                  widget.carbConsumed,
                  widget.carbTotal,
                  Colors.orange.shade500,
                ),
                SizedBox(height: 9),
                _buildMacroRow(
                  'Fat',
                  widget.fatConsumed,
                  widget.fatTotal,
                  Colors.purple.shade500,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMacroRow(String label, int consumed, int total, Color color) {
    double progress = consumed / total;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Text(
                '${consumed.toString().padLeft(3, '0')}/${total.toString().padLeft(3, '0')}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 1.0 ? 1.0 : progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
