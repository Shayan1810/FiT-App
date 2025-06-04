import 'package:flutter/material.dart';
import '/pages/home.dart';
import 'dart:io';
import '/pages/YourProfile.dart';
import '../pages/Nutrition/YourRecipe.dart';
import '../pages/Nutrition/YourFoodItems.dart';
import '../pages/Others/PowerLifting.dart';
import '../pages/Exercise/StrengthTraining.dart';
import '../pages/Exercise/Cardio.dart';
import '/pages/Program.dart';
import '/pages/AboutApp.dart';
import '/services/hive_service.dart';
import '../pages/CalorieLog/CalorieLog.dart';
class SideMenu extends StatefulWidget {
  @override
  _SideMenuState createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  String userName = 'YourName';

  @override
  void initState () {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final userData = HiveService.getUserData();
    if (userData != null) {
      setState(() {
        userName = userData.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.only(top: 35),
          children: [
            // Header Section
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B7CF6), Color(0xFFB794F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => YourProfile()),
                      );
                    },
                    borderRadius: BorderRadius.circular(40),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: HiveService.getUserProfileImage() != null
                        ? ClipOval(
                            child: Image.file(
                              File(HiveService.getUserProfileImage()!),
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            )
                          )
                        : Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B7CF6),
                            ),
                          ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'FiT Application',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Menu Items
            SizedBox(height: 20),
            
            // Home - Expandable
            _buildExpansionTile(
              title: 'Home',
              icon: Icons.home,
              children: [
                _buildMenuItem('Home Page', Icons.dashboard, () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomePage()),
                  );
                }),
                _buildMenuItem('Your Profile', Icons.person_outline, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => YourProfile()),
                  );
                }),
              ],
            ),
            
            // Nutrition - Expandable
            _buildExpansionTile(
              title: 'Nutrition',
              icon: Icons.restaurant,
              children: [
                _buildMenuItem('Calorie Log', Icons.receipt_long, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CalorieLog()),
                  );
                }),
                _buildMenuItem('Your Recipes', Icons.menu_book, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => YourRecipe()),
                  );
                }),
                _buildMenuItem('Your Food Items', Icons.menu_book, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => YourFoodItems()),
                  );
                }),
              ],
            ),
            
            // Exercise - Expandable
            _buildExpansionTile(
              title: 'Exercise',
              icon: Icons.fitness_center,
              children: [
                _buildMenuItem('PowerLifting', Icons.sports_gymnastics, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PowerLifting()),
                  );
                }),
                _buildMenuItem('Strength Training', Icons.sports_handball, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StrengthTraining()),
                  );
                }),
                _buildMenuItem('Cardiovascular', Icons.favorite, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Cardio()),
                  );
                }),
              ],
            ),
            
            // Program - Single Item
            _buildSingleMenuItem('Program', Icons.calendar_today, () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Program()),
              );
            }),
            
            // About - Single Item
            _buildSingleMenuItem('About', Icons.info_outline, () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AboutApp()),
              );
            }),
            
            SizedBox(height: 40),
            
            // Version Display at Bottom Center
            Container(
              padding: EdgeInsets.only(bottom: 20),
              child: Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... rest of your existing methods remain the same
  Widget _buildExpansionTile({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF8B7CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Color(0xFF8B7CF6),
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          iconColor: Color(0xFF8B7CF6),
          collapsedIconColor: Color(0xFF8B7CF6),
          children: children,
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.grey.shade600,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        hoverColor: Color(0xFF8B7CF6).withOpacity(0.1),
      ),
    );
  }

  Widget _buildSingleMenuItem(String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF8B7CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Color(0xFF8B7CF6),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
