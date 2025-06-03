import 'package:flutter/material.dart';

class CalorieChangeCard extends StatefulWidget {
  final int caloriesIn;
  final int caloriesOut;
  final AnimationController floatController;
  final double delay;

  CalorieChangeCard({
    required this.caloriesIn,
    required this.caloriesOut,
    required this.floatController,
    required this.delay,
  });

  @override
  _CalorieChangeCardState createState() => _CalorieChangeCardState();
}

class _CalorieChangeCardState extends State<CalorieChangeCard> {
  @override
  Widget build(BuildContext context) {
    int difference = (widget.caloriesIn - widget.caloriesOut).abs();
    bool isDeficit = widget.caloriesIn < widget.caloriesOut;
    String status = isDeficit ? 'Deficit' : 'Surplus';
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 6,
            spreadRadius: 0,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade200.withOpacity(0.3),
                  blurRadius: 4,
                  offset: Offset(1, 2),
                ),
              ],
            ),
            child: Icon(
              isDeficit ? Icons.trending_down : Icons.trending_up, 
              color: Colors.blue.shade600, 
              size: 24
            ),
          ),
          SizedBox(height: 12),
          Text(
            difference.toString().padLeft(4, '0'),
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Calorie $status',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
