import 'package:flutter/material.dart';

class WeightPage extends StatefulWidget {
  final double currentWeight;

  WeightPage({required this.currentWeight});

  @override
  _WeightPageState createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  late double _weight;
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _weight = widget.currentWeight.clamp(27.5, 150);
    // ScrollController will be initialized in build method after getting screen dimensions
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    // Responsive calculations based on screen size
    final double pixelsPerKg = screenWidth * 0.2; // 16% of screen width per kg
    final double tickWidth = screenWidth * 0.02; // 1.5% of screen width per tick
    final double maxScrollOffset = (122.5 * pixelsPerKg) - (screenWidth * 0.5); // Adjusted for centering
    
    // Calculate initial scroll offset with proper centering
    double initialOffset = ((_weight - 27.5) * pixelsPerKg) - (screenWidth * 0.5);
    initialOffset = initialOffset.clamp(0.0, maxScrollOffset);
    
    // Initialize ScrollController
    _scrollController = ScrollController(initialScrollOffset: initialOffset);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Purple progress line on top - responsive
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.055, // 5.5% of screen width
                vertical: screenHeight * 0.012, // 1.2% of screen height
              ),
              height: screenHeight * 0.005, // 0.5% of screen height
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ((_weight - 27.5) / 122.5).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF8B7CF6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: screenHeight * 0.048), // ~4.8% of screen height
            
            // Title text - responsive font size
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.055),
              child: Text(
                'What is your weight?',
                style: TextStyle(
                  fontSize: screenWidth * 0.075, // 7.5% of screen width
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            SizedBox(height: screenHeight * 0.12), // 12% of screen height
            
            // Weight display text - responsive font size
            Text(
              '${_weight.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: screenWidth * 0.19, // 19% of screen width
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B7CF6),
              ),
            ),
            
            Text(
              'kg',
              style: TextStyle(
                fontSize: screenWidth * 0.065, // 6.5% of screen width
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            SizedBox(height: screenHeight * 0.048), // ~4.8% of screen height
            
            // Scrolling measurement bar - responsive
            Container(
              height: screenHeight * 0.072, // 7.2% of screen height
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (notification is ScrollUpdateNotification) {
                    double offset = _scrollController.offset;
                    // Clamp scroll offset to prevent going beyond limits
                    offset = offset.clamp(0.0, maxScrollOffset);
                    
                    setState(() {
                      double rawWeight = 27.5 + ((offset + (screenWidth * 0.5)) / pixelsPerKg);
                      _weight = (rawWeight * 10).round() / 10;
                      _weight = _weight.clamp(27.5, 150);
                    });
                  }
                  return true;
                },
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.4925), // Center padding
                    physics: ClampingScrollPhysics(),
                    itemCount: 1221, // 122.5 kg range * 10 for 0.1 increments
                    itemBuilder: (context, index) {
                      double weight = 27.5 + (index * 0.1);
                      if (weight > 150) return SizedBox.shrink();
                      
                      bool isMajor = (weight * 10).round() % 10 == 0;
                      bool isHalfKg = (weight * 10).round() % 5 == 0;
                      bool isSelected = ((_weight * 10).round() == ((weight+2.5) * 10).round());
                      
                      return Container(
                        width: tickWidth,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: isMajor 
                                ? screenHeight * 0.03 // 4.8% for major ticks
                                : (isHalfKg 
                                    ? screenHeight * 0.048 // 3% for half kg
                                    : screenHeight * 0.018), // 1.8% for minor ticks
                              width: screenWidth * 0.005, // 0.5% of screen width
                              decoration: BoxDecoration(
                                color: isSelected
                                  ? Color(0xFF8B7CF6) 
                                  : (isHalfKg
                                      ? Colors.grey.shade600 
                                      : (isMajor ? Colors.grey.shade500 : Colors.grey.shade400)),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            // Purple vertical line on bottom - responsive
            Container(
              width: screenWidth * 0.005, // 0.5% of screen width
              height: screenHeight * 0.072, // 7.2% of screen height
              margin: EdgeInsets.only(top: screenHeight * 0.012), // 1.2% margin
              decoration: BoxDecoration(
                color: Color(0xFF8B7CF6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            
            Spacer(),
            
            // Continue button - responsive
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(screenWidth * 0.055), // 5.5% margin
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _weight);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B7CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.043), // 4.3% border radius
                  ),
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.022), // 2.2% vertical padding
                  elevation: 8,
                  shadowColor: Color(0xFF8B7CF6).withOpacity(0.3),
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.048, // 4.8% of screen width
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
