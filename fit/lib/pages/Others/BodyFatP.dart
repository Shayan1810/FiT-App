import 'package:flutter/material.dart';

class BodyFatPPage extends StatelessWidget {
  final double currentBodyFat;
  final double weight;
  final double height;
  final int age;
  final String gender;

  BodyFatPPage({
    required this.currentBodyFat,
    required this.weight,
    required this.height,
    required this.age,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Body Fat Calculator'),
        backgroundColor: Color(0xFF8B7CF6),
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B7CF6), Color(0xFFB794F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF8B7CF6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.calculate,
                color: Colors.white,
                size: 60,
              ),
            ),
            SizedBox(height: 40),
            Text(
              'Body Fat Calculator',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B7CF6),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Calculate your body fat percentage using various methods',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            
            // User Info Display
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Your Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Weight:', style: TextStyle(fontSize: 16)),
                      Text('${weight.toStringAsFixed(1)} kg', 
                           style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Height:', style: TextStyle(fontSize: 16)),
                      Text('${height.toStringAsFixed(0)} cm', 
                           style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Age:', style: TextStyle(fontSize: 16)),
                      Text('$age years', 
                           style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gender:', style: TextStyle(fontSize: 16)),
                      Text(gender, 
                           style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 40),
            
            // Calculate Button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Simple calculation - you can implement more sophisticated algorithms
                  double calculatedBodyFat = _calculateBodyFat();
                  Navigator.pop(context, calculatedBodyFat);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B7CF6),
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Calculate Body Fat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateBodyFat() {
    // Simple body fat calculation using BMI-based estimation
    // Note: This is a basic estimation. Real body fat calculation requires more sophisticated methods
    double heightInM = height / 100;
    double bmi = weight / (heightInM * heightInM);
    
    double bodyFat;
    if (gender.toLowerCase() == 'male') {
      bodyFat = (1.20 * bmi) + (0.23 * age) - 16.2;
    } else {
      bodyFat = (1.20 * bmi) + (0.23 * age) - 5.4;
    }
    
    // Ensure reasonable bounds
    bodyFat = bodyFat.clamp(3.0, 50.0);
    
    return bodyFat;
  }
}
