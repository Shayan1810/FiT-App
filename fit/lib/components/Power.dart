import 'package:flutter/material.dart';
import 'dart:math' as math;

class PowerCard extends StatefulWidget {
  final int squats;
  final int benchPress;
  final int deadlift;
  final AnimationController floatController;

  PowerCard({
    Key? key,
    required this.squats,
    required this.benchPress,
    required this.deadlift,
    required this.floatController,
  }) : super(key: key);

  @override
  _PowerCardState createState() => _PowerCardState();
}

class _PowerCardState extends State<PowerCard> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.floatController,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(0.02 * math.sin(widget.floatController.value * 2 * math.pi + 0.5))
            ..translate(0.0, widget.floatController.value * -3),
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
                  'Power Lifts',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 20),
                _buildPowerRow('Squats', widget.squats, Icons.fitness_center),
                SizedBox(height: 16),
                _buildPowerRow('Bench Press', widget.benchPress, Icons.fitness_center),
                SizedBox(height: 16),
                _buildPowerRow('Deadlift', widget.deadlift, Icons.fitness_center),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPowerRow(String label, int value, IconData icon) {
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
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.purple.shade600,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Text(
            value.toString().padLeft(3, '0'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
