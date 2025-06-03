import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/hive_service.dart';
import '../models/user_data.dart';
import '../pages/Others/Weight.dart';
import '../pages/Others/BodyFatP.dart';

class YourProfile extends StatefulWidget {
  @override
  _YourProfileState createState() => _YourProfileState();
}

class _YourProfileState extends State<YourProfile> {
  bool isEditing = false;
  final ImagePicker _picker = ImagePicker();
  
  // Controllers for editing
  late TextEditingController nameController;
  late TextEditingController bodyFatController;
  late TextEditingController heightController;
  late TextEditingController ageController;
  
  String selectedGender = 'Other';
  DateTime selectedDateOfBirth = DateTime.now().subtract(Duration(days: 365 * 25));
  String? profileImagePath;
  double currentWeight = 65.0;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    nameController = TextEditingController();
    bodyFatController = TextEditingController();
    heightController = TextEditingController();
    ageController = TextEditingController();
  }

  void _loadUserData() {
    final userData = HiveService.getUserData();
    if (userData != null) {
      setState(() {
        nameController.text = userData.name;
        currentWeight = userData.weight;
        bodyFatController.text = userData.bodyFatPercentage.toString();
        heightController.text = userData.height.toString();
        ageController.text = userData.age.toString();
        selectedGender = userData.gender;
        selectedDateOfBirth = userData.dateOfBirth;
        profileImagePath = userData.profileImagePath;
      });
    } else {
      // Set default values
      nameController.text = 'Your Name';
      currentWeight = 65.0;
      bodyFatController.text = '15.0';
      heightController.text = '175.0';
      ageController.text = '25';
      selectedGender = 'Other';
      selectedDateOfBirth = DateTime.now().subtract(Duration(days: 365 * 25));
    }
  }

  Future<void> _pickImage() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Color(0xFF8B7CF6)),
              title: Text('Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 1024,
                  maxHeight: 1024,
                );
                if (image != null) {
                  setState(() {
                    profileImagePath = image.path;
                  });
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Color(0xFF8B7CF6)),
              title: Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                  maxWidth: 1024,
                  maxHeight: 1024,
                );
                if (image != null) {
                  setState(() {
                    profileImagePath = image.path;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editWeight() async {
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
      await HiveService.updateWeight(result);
    }
  }

  Future<void> _calculateBodyFat() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BodyFatPPage(
          currentBodyFat: double.tryParse(bodyFatController.text) ?? 15.0,
          weight: currentWeight,
          height: double.tryParse(heightController.text) ?? 175.0,
          age: int.tryParse(ageController.text) ?? 25,
          gender: selectedGender,
        ),
      ),
    );
    
    if (result != null && result is double) {
      setState(() {
        bodyFatController.text = result.toStringAsFixed(1);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDateOfBirth,
      firstDate: DateTime.now().subtract(Duration(days: 365 * 120)),
      lastDate: DateTime.now().subtract(Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Color(0xFF8B7CF6)),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDateOfBirth) {
      final dobError = _validateDateOfBirth(picked);
      if (dobError == null) {
        setState(() {
          selectedDateOfBirth = picked;
          final age = DateTime.now().difference(picked).inDays ~/ 365;
          ageController.text = age.toString();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dobError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _validateName(String value) {
    if (value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  String? _validateBodyFat(String value) {
    final double? bodyFat = double.tryParse(value);
    if (bodyFat == null) {
      return 'Please enter a valid number';
    }
    if (bodyFat < 0 || bodyFat >= 100) {
      return 'Body fat must be between 0 and 99.9%';
    }
    return null;
  }

  String? _validateHeight(String value) {
    final double? height = double.tryParse(value);
    if (height == null) {
      return 'Please enter a valid number';
    }
    if (height <= 0 || height > 300) {
      return 'Please enter a valid height (1-300 cm)';
    }
    return null;
  }

  String? _validateAge(String value) {
    final int? age = int.tryParse(value);
    if (age == null) {
      return 'Please enter a valid number';
    }
    if (age <= 0 || age >= 120) {
      return 'Age must be between 1 and 119 years';
    }
    return null;
  }

  String? _validateDateOfBirth(DateTime date) {
    final DateTime tenYearsAgo = DateTime.now().subtract(Duration(days: 365 * 10));
    final DateTime maxAge = DateTime.now().subtract(Duration(days: 365 * 120));
    
    if (date.isAfter(tenYearsAgo)) {
      return 'Date of birth must be at least 10 years ago';
    }
    if (date.isBefore(maxAge)) {
      return 'Date of birth cannot be more than 120 years ago';
    }
    return null;
  }

  bool _validateAllFields() {
    List<String> errors = [];

    final nameError = _validateName(nameController.text);
    if (nameError != null) errors.add('Name: $nameError');

    final bodyFatError = _validateBodyFat(bodyFatController.text);
    if (bodyFatError != null) errors.add('Body Fat: $bodyFatError');

    final heightError = _validateHeight(heightController.text);
    if (heightError != null) errors.add('Height: $heightError');

    final ageError = _validateAge(ageController.text);
    if (ageError != null) errors.add('Age: $ageError');

    final dobError = _validateDateOfBirth(selectedDateOfBirth);
    if (dobError != null) errors.add('Date of Birth: $dobError');

    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Validation Errors'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors.map((error) => Text('• $error')).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: Color(0xFF8B7CF6))),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _saveProfile() async {
    if (!_validateAllFields()) return;

    try {
      final userData = UserData(
        name: nameController.text.trim(),
        weight: currentWeight,
        caloriesIn: HiveService.getUserData()?.caloriesIn ?? 0,
        caloriesOut: HiveService.getUserData()?.caloriesOut ?? 0,
        lastUpdated: DateTime.now(),
        bodyFatPercentage: double.parse(bodyFatController.text),
        height: double.parse(heightController.text),
        age: int.parse(ageController.text),
        gender: selectedGender,
        dateOfBirth: selectedDateOfBirth,
        profileImagePath: profileImagePath,
      );

      await HiveService.saveUserData(userData);
      
      setState(() {
        isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Color(0xFF8B7CF6),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    bodyFatController.dispose();
    heightController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'Your Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          if (!isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: Color(0xFF8B7CF6)),
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Image Section
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFF8B7CF6), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF8B7CF6).withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: profileImagePath != null
                        ? Image.file(
                            File(profileImagePath!),
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF8B7CF6), Color(0xFFB794F6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                if (isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Color(0xFF8B7CF6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: 30),
            
            // Profile Details
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildProfileField('Name', nameController.text, nameController, Icons.person, true),
                  _buildDivider(),
                  _buildWeightField(),
                  _buildDivider(),
                  _buildBodyFatField(),
                  _buildDivider(),
                  _buildProfileField('Height', '${heightController.text} cm', heightController, Icons.height, true),
                  _buildDivider(),
                  _buildProfileField('Age', '${ageController.text} years', ageController, Icons.calendar_today, false), // Age not directly editable
                  _buildDivider(),
                  _buildGenderField(),
                  _buildDivider(),
                  _buildDateField(),
                ],
              ),
            ),
            
            if (isEditing) ...[
              SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isEditing = false;
                          _loadUserData();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8B7CF6),
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value, TextEditingController controller, IconData icon, bool editable) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF8B7CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Color(0xFF8B7CF6), size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                (isEditing && editable)
                    ? TextField(
                        controller: controller,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF8B7CF6)),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF8B7CF6), width: 2),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightField() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF8B7CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.monitor_weight, color: Color(0xFF8B7CF6), size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weight',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${currentWeight.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    if (isEditing)
                      GestureDetector(
                        onTap: _editWeight,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF8B7CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFF8B7CF6).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                color: Color(0xFF8B7CF6),
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8B7CF6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyFatField() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF8B7CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.fitness_center, color: Color(0xFF8B7CF6), size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body Fat Percentage',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: (isEditing)
                          ? TextField(
                              controller: bodyFatController,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF8B7CF6)),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF8B7CF6), width: 2),
                                ),
                                contentPadding: EdgeInsets.zero,
                                suffixText: '%',
                              ),
                            )
                          : Text(
                              '${bodyFatController.text}%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: _calculateBodyFat,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF8B7CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF8B7CF6).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calculate,
                              color: Color(0xFF8B7CF6),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Calculate',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B7CF6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderField() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF8B7CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person_outline, color: Color(0xFF8B7CF6), size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gender',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                isEditing
                    ? DropdownButton<String>(
                        value: selectedGender,
                        underline: Container(height: 1, color: Color(0xFF8B7CF6)),
                        items: ['Male', 'Female', 'Other'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedGender = newValue!;
                          });
                        },
                      )
                    : Text(
                        selectedGender,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF8B7CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.cake, color: Color(0xFF8B7CF6), size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date of Birth',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    isEditing
                        ? GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFF8B7CF6))),
                              ),
                              child: Text(
                                '${selectedDateOfBirth.day}/${selectedDateOfBirth.month}/${selectedDateOfBirth.year}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            '${selectedDateOfBirth.day}/${selectedDateOfBirth.month}/${selectedDateOfBirth.year}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                    if (isEditing)
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF8B7CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFF8B7CF6).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Color(0xFF8B7CF6),
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8B7CF6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey.shade200,
      indent: 56,
    );
  }
}
