import 'package:flutter/material.dart';

class Cardio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cardiovascular'),
        backgroundColor: Color(0xFF8B7CF6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Cardiovascular Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
