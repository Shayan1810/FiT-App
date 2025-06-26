import 'package:Fit/pages/CalorieLog/CalorieLog.dart';
import 'package:flutter/material.dart';
import '/components/calorie-change-card.dart';
import '/components/calorie-in-card.dart';
import '/components/calorie-out-card.dart';
import '/components/menu.dart';
import '/components/weight-card.dart';
import '/components/Macro.dart';
import '/components/Expend.dart';
import 'Others/Weight.dart';
import '../services/hive_service.dart';
import '../models/user_data.dart';
import '../models/activity_data.dart';
import '../models/calorie_log.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _floatController;
  late AnimationController _cardSwitchController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int caloriesIn = 0;
  int caloriesOut = 0;
  double currentWeight = 65.0;
  int selectedCardIndex = 0;
  int _previousCardIndex = 0;

  int get proteinConsumed => (todayLog.meals).fold(0, (sum, meal) => sum + meal.protein.toInt());
  int get carbConsumed => (todayLog.meals).fold(0, (sum, meal) => sum + meal.carbs.toInt());
  int get fatConsumed => (todayLog.meals).fold(0, (sum, meal) => sum + meal.fat.toInt());

  int get bmr => userData?.bmr?.toInt() ?? 1650;
  int get neatCardio => activityData?.neatCalories.toInt() ?? 450;
  double get foodThermogenesis => (proteinConsumed + (carbConsumed + fatConsumed) * (13 / 90)).toDouble();
  int get totalCaloriesOut => (bmr + foodThermogenesis + neatCardio).toInt();

  UserData? get userData => HiveService.getUserData();
  ActivityData? get activityData => HiveService.getActivityData();
  DayLog get todayLog => _getTodayLog();

  DayLog _getTodayLog() {
    final now = DateTime.now();
    final log = _logBox.values.firstWhere(
      (log) => log.date.year == now.year &&
               log.date.month == now.month &&
               log.date.day == now.day,
      orElse: () => DayLog(date: now),
    );

    if (!_logBox.values.contains(log)) {
      _logBox.put(_getTodayKey(), log);
    }
    return log;
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Box get _logBox => Hive.box('calorieLogBox');

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _floatController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _cardSwitchController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _updateCalorieData();
  }

  void _updateCalorieData() {
    setState(() {
      // Use type-safe box access
      caloriesIn = (_logBox.values.expand((log) => log.meals)).fold(
        0, 
        (sum, meal) => (sum + meal.calorie as num).toInt()
      );
      caloriesOut = totalCaloriesOut;
      currentWeight = userData?.weight ?? 65.0;
    });
  }

  void _checkAndResetCalories() {
    DateTime now = DateTime.now();
    if (now.hour == 12 && now.minute == 0) {
      setState(() {
        caloriesIn = 0;
        caloriesOut = 0;
      });
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _floatController.dispose();
    _cardSwitchController.dispose();
    super.dispose();
  }

  void _editWeight() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightPage(currentWeight: currentWeight),
      ),
    );
    if (result != null && result is double) {
      setState(() {
        currentWeight = result;
      });
    }
  }

  void _selectCard(int index) {
    if (selectedCardIndex != index) {
      setState(() {
        _previousCardIndex = selectedCardIndex;
        selectedCardIndex = index;
      });
      _cardSwitchController.forward(from: 0);
    }
  }

  Widget _buildSelectedCard() {
    switch (selectedCardIndex) {
      case 0:
        return MacroCard(
          key: ValueKey('macro'),
          proteinConsumed: 210,
          proteinTotal: 150,
          carbConsumed: 215,
          carbTotal: 130,
          fatConsumed: 220,
          fatTotal: 60,
          floatController: _floatController,
        );
      case 1:
        return ExpendCard(
          key: ValueKey('expend'),
          bmr: 1532,
          neatCardio: 68,
          foodThermogenesis: 250,
          floatController: _floatController,
        );
      default:
        return MacroCard(
          key: ValueKey('macro'),
          proteinConsumed: 210,
          proteinTotal: 150,
          carbConsumed: 215,
          carbTotal: 130,
          fatConsumed: 220,
          fatTotal: 60,
          floatController: _floatController,
        );
    }
  }

  int alpha = 3680;
  int beta = 1600;

  Widget _buildCircularButtonBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCircularButton(
            icon: Icons.restaurant,
            isSelected: selectedCardIndex == 0,
            onTap: () => _selectCard(0),
          ),
          SizedBox(width: 8),
          _buildCircularButton(
            icon: Icons.local_fire_department,
            isSelected: selectedCardIndex == 1,
            onTap: () => _selectCard(1),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Color(0xFF8B7CF6) : Colors.grey.shade700,
          boxShadow: isSelected ? [
            BoxShadow(
              color: Color(0xFF8B7CF6).withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
              offset: Offset(0, 5),
            ),
          ] : [],
        ),
        child: AnimatedScale(
          duration: Duration(milliseconds: 200),
          scale: isSelected ? 1.1 : 1.0,
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  String _getCardKey(int index) {
    switch (index) {
      case 0:
        return 'macro';
      case 1:
        return 'expend';
      default:
        return 'macro';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: SideMenu(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _floatController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _floatController.value * 2),
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(width: 8),
                            Text(
                              'FiT Application',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'A Nebula Project by Shayan Zafar (22324017)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.purple.shade100,
                        child: Icon(Icons.person, color: Colors.purple),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Metrics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CalorieLog()),
                              );
                            },
                            child: CalorieInCard(
                              caloriesIn: alpha,
                              floatController: _floatController,
                              delay: 0.0,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: CalorieOutCard(
                            caloriesOut: beta,
                            floatController: _floatController,
                            delay: 0.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CalorieChangeCard(
                            caloriesIn: alpha,
                            caloriesOut: beta,
                            floatController: _floatController,
                            delay: 0.1,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: WeightCard(
                            weight: currentWeight,
                            floatController: _floatController,
                            delay: 0.3,
                            onEditPressed: _editWeight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              AnimatedSwitcher(
                duration: Duration(milliseconds: 500),
                reverseDuration: Duration(milliseconds: 500),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  bool movingForward = selectedCardIndex > _previousCardIndex;
                  bool movingBackward = selectedCardIndex < _previousCardIndex;
                  if (child.key == ValueKey(_getCardKey(selectedCardIndex))) {
                    Offset beginOffset;
                    if (movingForward) {
                      beginOffset = Offset(1.0, 0.0);
                    } else if (movingBackward) {
                      beginOffset = Offset(-1.0, 0.0);
                    } else {
                      beginOffset = Offset.zero;
                    }
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: beginOffset,
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: FadeTransition(
                        opacity: Tween<double>(
                          begin: 0.0,
                          end: 1.0,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Interval(0.0, 0.8, curve: Curves.easeOut),
                        )),
                        child: child,
                      ),
                    );
                  } else {
                    Offset endOffset;
                    if (movingForward) {
                      endOffset = Offset(-1.0, 0.0);
                    } else if (movingBackward) {
                      endOffset = Offset(1.0, 0.0);
                    } else {
                      endOffset = Offset.zero;
                    }
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset.zero,
                        end: endOffset,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInCubic,
                      )),
                      child: FadeTransition(
                        opacity: Tween<double>(
                          begin: 1.0,
                          end: 0.0,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Interval(0.2, 1.0, curve: Curves.easeIn),
                        )),
                        child: child,
                      ),
                    );
                  }
                },
                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: _buildSelectedCard(),
              ),
              SizedBox(height: 20),
              _buildCircularButtonBar(),
              SizedBox(height: 24),
              _build3DCaloriesSection(),
              SizedBox(height: 24),
              _build3DStepsSection(),
              SizedBox(height: 24),
              _build3DActivityChart(),
              SizedBox(height: 24),
              _build3DFoodSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DCaloriesSection() {
    return Container();
  }

  Widget _build3DStepsSection() {
    return Container();
  }

  Widget _build3DActivityChart() {
    return Container();
  }

  Widget _build3DFoodSection() {
    return Container();
  }
}

class ActivityChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF8B7CF6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = Color(0xFF8B7CF6).withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final path = Path();
    final fillPath = Path();
    List<double> points = [0.3, 0.7, 0.4, 0.8, 0.6, 0.9, 0.5];
    for (int i = 0; i < points.length; i++) {
      double x = (size.width / (points.length - 1)) * i;
      double y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
