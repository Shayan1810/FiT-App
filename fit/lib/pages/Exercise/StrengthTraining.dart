import 'package:flutter/material.dart';

class StrengthTraining extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Strength Training'),
        backgroundColor: Color(0xFF8B7CF6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Strength Training Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
