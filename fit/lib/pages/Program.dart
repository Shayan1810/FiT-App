import 'package:flutter/material.dart';

class Program extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Program'),
        backgroundColor: Color(0xFF8B7CF6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Program Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
