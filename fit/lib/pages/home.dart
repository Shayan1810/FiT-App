import 'package:flutter/material.dart';
import '/components/calorie-change-card.dart';
import '/components/calorie-in-card.dart';
import '/components/calorie-out-card.dart';
import '/components/menu.dart';
import '/components/weight-card.dart';
import '/components/Macro.dart';
import '/components/Expend.dart';
import '/components/Power.dart';
import 'Others/Weight.dart';
import '/pages/Nutrition/IN.dart';
import '/pages/Exercise/OUT.dart';

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
  int selectedCardIndex = 0; // 0: Macro, 1: Expend, 2: Power
  int _previousCardIndex = 0; // Track previous selection for direction
  
  // Macronutrient data
  int proteinConsumed = 45;
  int proteinTotal = 150;
  int carbConsumed = 120;
  int carbTotal = 300;
  int fatConsumed = 35;
  int fatTotal = 80;
  
  // Energy expenditure data
  int bmr = 1650;
  int neatCardio = 450;
  int foodThermogenesis = 120;

  // Power lifting data
  int squats = 150;
  int benchPress = 120;
  int deadlift = 200;

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
    
    _checkAndResetCalories();
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
          proteinConsumed: proteinConsumed,
          proteinTotal: proteinTotal,
          carbConsumed: carbConsumed,
          carbTotal: carbTotal,
          fatConsumed: fatConsumed,
          fatTotal: fatTotal,
          floatController: _floatController,
        );
      case 1:
        return ExpendCard(
          key: ValueKey('expend'),
          bmr: bmr,
          neatCardio: neatCardio,
          foodThermogenesis: foodThermogenesis,
          floatController: _floatController,
        );
      case 2:
        return PowerCard(
          key: ValueKey('power'),
          squats: squats,
          benchPress: benchPress,
          deadlift: deadlift,
          floatController: _floatController,
        );
      default:
        return MacroCard(
          key: ValueKey('macro'),
          proteinConsumed: proteinConsumed,
          proteinTotal: proteinTotal,
          carbConsumed: carbConsumed,
          carbTotal: carbTotal,
          fatConsumed: fatConsumed,
          fatTotal: fatTotal,
          floatController: _floatController,
        );
    }
  }

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
          SizedBox(width: 8),
          _buildCircularButton(
            icon: Icons.flash_on,
            isSelected: selectedCardIndex == 2,
            onTap: () => _selectCard(2),
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
                          'Hi, Shayan',
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
                                MaterialPageRoute(builder: (context) => InPage()),
                              );
                            },
                            child: CalorieInCard(
                              caloriesIn: caloriesIn,
                              floatController: _floatController,
                              delay: 0.0,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => OutPage()),
                              );
                            },
                            child: CalorieOutCard(
                              caloriesOut: caloriesOut,
                              floatController: _floatController,
                              delay: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CalorieChangeCard(
                            caloriesIn: caloriesIn,
                            caloriesOut: caloriesOut,
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
              
              // Enhanced AnimatedSwitcher with Bidirectional Slide Animation
              AnimatedSwitcher(
                duration: Duration(milliseconds: 500),
                reverseDuration: Duration(milliseconds: 500),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Determine the direction of movement
                  bool movingForward = selectedCardIndex > _previousCardIndex;
                  bool movingBackward = selectedCardIndex < _previousCardIndex;
                  
                  // Create different animations for incoming and outgoing
                  if (child.key == ValueKey(_getCardKey(selectedCardIndex))) {
                    // This is the incoming card
                    Offset beginOffset;
                    if (movingForward) {
                      beginOffset = Offset(1.0, 0.0); // Come from right
                    } else if (movingBackward) {
                      beginOffset = Offset(-1.0, 0.0); // Come from left
                    } else {
                      beginOffset = Offset.zero; // No movement
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
                    // This is the outgoing card
                    Offset endOffset;
                    if (movingForward) {
                      endOffset = Offset(-1.0, 0.0); // Exit to left
                    } else if (movingBackward) {
                      endOffset = Offset(1.0, 0.0); // Exit to right
                    } else {
                      endOffset = Offset.zero; // No movement
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
              
              // Circular Button Bar matching the image
              SizedBox(height: 20),
              _buildCircularButtonBar(),
              
              SizedBox(height: 24),
              // Removed ExpendCard from here as requested
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

  String _getCardKey(int index) {
    switch (index) {
      case 0:
        return 'macro';
      case 1:
        return 'expend';
      case 2:
        return 'power';
      default:
        return 'macro';
    }
  }

  // Keep all other existing methods unchanged
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
