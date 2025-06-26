import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/user_data.dart';
import '../../models/activity_data.dart';
import '../../services/hive_service.dart';

class ExercisePage extends StatefulWidget {
  @override
  _ExercisePageState createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  final _neatController = TextEditingController();
  final _geminiApiKey = 'AIzaSyCfShRiOmxuOOvwbS3FzrKkBKUq8Z0XEDs';
  IntegrationMode _integrationMode = IntegrationMode.manual;
  double? _bmr;
  double? _neatCalories;
  bool _isCalculatingBmr = false;
  String? _bmrError;

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  void _loadStoredData() {
    final userData = HiveService.getUserData();
    final activityData = HiveService.getActivityData();

    if (userData != null && userData.bmr != null) {
      _bmr = userData.bmr;
    }

    if (activityData != null) {
      _neatCalories = activityData.neatCalories;
      _neatController.text = _neatCalories!.toStringAsFixed(0);
    }

    setState(() {});
  }

  Future<void> _updateBMR() async {
    final userData = HiveService.getUserData();
    if (userData == null || userData.bodyFatPercentage == null) {
      setState(() => _bmrError = 'Complete profile with body fat % first');
      return;
    }

    try {
      setState(() {
        _isCalculatingBmr = true;
        _bmrError = null;
      });

      final newBmr = await _calculateBMRWithGemini(userData);
      
      // Update and persist new BMR
      final updatedUserData = userData.copyWith(bmr: newBmr);
      await HiveService.saveUserData(updatedUserData);

      setState(() => _bmr = newBmr);
    } catch (e) {
      setState(() => _bmrError = 'Failed to calculate BMR: ${e.toString()}');
    } finally {
      setState(() => _isCalculatingBmr = false);
    }
  }

  Future<double> _calculateBMRWithGemini(UserData userData) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _geminiApiKey,
    );
    
    final prompt = '''
Calculate Basal Metabolic Rate (BMR) in kcal/day usinf Katch-McArdle Formula considering these parameters:
- Weight: ${userData.weight} kg
- Height: ${userData.height} cm
- Age: ${userData.age} years
- Gender: ${userData.gender}
- Body Fat Percentage: ${userData.bodyFatPercentage}%

Provide only the numerical result without any units or explanations.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final textResponse = response.text?.trim() ?? '';
    
    final bmr = double.tryParse(textResponse);
    if (bmr == null) {
      throw Exception('Invalid response from Gemini: $textResponse');
    }
    
    return bmr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calories Burned')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SegmentedButton<IntegrationMode>(
              segments: const [
                ButtonSegment(
                  value: IntegrationMode.samsung,
                  label: Text('Samsung Health'),
                  icon: Icon(Icons.health_and_safety),
                ),
                ButtonSegment(
                  value: IntegrationMode.manual,
                  label: Text('Manual'),
                  icon: Icon(Icons.edit),
                ),
              ],
              selected: {_integrationMode},
            ),
            
            const SizedBox(height: 20),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Basal Metabolic Rate (BMR)',
                            style: Theme.of(context).textTheme.titleMedium),
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: _updateBMR,
                          tooltip: 'Recalculate BMR',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isCalculatingBmr)
                      LinearProgressIndicator()
                    else if (_bmrError != null)
                      Text(_bmrError!, style: TextStyle(color: Colors.red))
                    else if (_bmr != null)
                      Text('${_bmr!.toStringAsFixed(0)} kcal/day',
                          style: TextStyle(fontSize: 16))
                    else
                      Text('Press refresh button to calculate BMR',
                          style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Card(
              color: _integrationMode == IntegrationMode.samsung 
                  ? Colors.grey[200]
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEAT + Cardio',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _neatController,
                      enabled: _integrationMode == IntegrationMode.manual,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Calories burned',
                        suffixText: 'kcal',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final calories = double.tryParse(value);
                        if (calories != null) {
                          HiveService.saveActivityData(
                            ActivityData(neatCalories: calories)
                          );
                        }
                      },
                    ),
                    if (_integrationMode == IntegrationMode.samsung)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Data synced from Samsung Health',
                            style: TextStyle(color: Colors.grey)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum IntegrationMode { samsung, manual }
