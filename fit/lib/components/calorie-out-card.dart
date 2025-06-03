import 'package:flutter/material.dart';
import 'dart:math' as math;

class CalorieOutCard extends StatefulWidget {
  final int caloriesOut;
  final AnimationController floatController;
  final double delay;

  CalorieOutCard({
    required this.caloriesOut,
    required this.floatController,
    required this.delay,
  });

  @override
  _CalorieOutCardState createState() => _CalorieOutCardState();
}

class _CalorieOutCardState extends State<CalorieOutCard> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.floatController,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(0.05 * math.sin(widget.floatController.value * 2 * math.pi + widget.delay))
            ..rotateY(0.05 * math.cos(widget.floatController.value * 2 * math.pi + widget.delay))
            ..scale(1.0 + (0.02 * math.sin(widget.floatController.value * 2 * math.pi + widget.delay))),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B7CF6), Color(0xFFB794F6), Color(0xFF9F7AEA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF8B7CF6).withOpacity(0.5),
                  blurRadius: 25,
                  spreadRadius: 2,
                  offset: Offset(0, 12),
                ),
                BoxShadow(
                  color: Color(0xFF8B7CF6).withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: Offset(0, 25),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: Offset(-3, -3),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(3, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: Offset(2, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 5,
                        offset: Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: Icon(Icons.local_fire_department, color: Colors.white, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  widget.caloriesOut.toString().padLeft(4, '0'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black.withOpacity(0.3),
                        offset: Offset(2.0, 2.0),
                      ),
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.white.withOpacity(0.2),
                        offset: Offset(-1.0, -1.0),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Calories OUT',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    shadows: [
                      Shadow(
                        blurRadius: 5.0,
                        color: Colors.black.withOpacity(0.2),
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
