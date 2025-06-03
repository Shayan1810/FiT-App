import 'package:flutter/material.dart';

class PowerLifting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PowerLifting'),
        backgroundColor: Color(0xFF8B7CF6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'PowerLifting Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
