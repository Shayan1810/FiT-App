import 'package:flutter/material.dart';
import '../../services/hive_service.dart';
import '../../models/food_item.dart';

class YourFoodItems extends StatefulWidget {
  @override
  _YourFoodItemsState createState() => _YourFoodItemsState();
}

class _YourFoodItemsState extends State<YourFoodItems> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  late TextEditingController nameController;
  late TextEditingController tagController;
  late TextEditingController quantityController;
  late TextEditingController proteinController;
  late TextEditingController carbohydrateController;
  late TextEditingController fatController;
  late TextEditingController searchController;
  
  List<FoodItem> foodItems = [];
  List<FoodItem> filteredFoodItems = [];
  bool isAddingItem = false;
  FoodItem? editingItem;
  String selectedUnit = 'unit';
  String sortBy = 'protein%'; // Removed 'name' option
  bool searchByTag = false; // Toggle for search basis (false = name, true = tag)
  String calculatedCalories = '0'; // For real-time calorie display
  
  final List<String> unitOptions = ['unit', 'gram', 'mL', 'Litre'];
  final List<String> sortOptions = ['protein%', 'carb%', 'fat%']; // Removed 'name'
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadFoodItems();
  }

  void _initializeControllers() {
    nameController = TextEditingController();
    tagController = TextEditingController();
    quantityController = TextEditingController();
    proteinController = TextEditingController();
    carbohydrateController = TextEditingController();
    fatController = TextEditingController();
    searchController = TextEditingController();
    
    searchController.addListener(_filterFoodItems);
    
    // Add listeners for real-time calorie calculation
    proteinController.addListener(_updateCaloriesRealTime);
    carbohydrateController.addListener(_updateCaloriesRealTime);
    fatController.addListener(_updateCaloriesRealTime);
  }

  // Real-time calorie update method
  void _updateCaloriesRealTime() {
    setState(() {
      calculatedCalories = _getCalculatedCalories();
    });
  }

  void _loadFoodItems() {
    setState(() {
      foodItems = HiveService.getAllFoodItems();
      _sortFoodItems();
      filteredFoodItems = foodItems;
    });
  }

  void _sortFoodItems() {
    switch (sortBy) {
      case 'protein%':
        foodItems.sort((a, b) => _calculateProteinPercentage(b).compareTo(_calculateProteinPercentage(a)));
        break;
      case 'carb%':
        foodItems.sort((a, b) => _calculateCarbPercentage(b).compareTo(_calculateCarbPercentage(a)));
        break;
      case 'fat%':
        foodItems.sort((a, b) => _calculateFatPercentage(b).compareTo(_calculateFatPercentage(a)));
        break;
    }
  }

  double _calculateProteinPercentage(FoodItem item) {
    if (item.calories == 0) return 0;
    return (item.protein * 4) / item.calories * 100;
  }

  double _calculateCarbPercentage(FoodItem item) {
    if (item.calories == 0) return 0;
    return (item.carbohydrate * 4) / item.calories * 100;
  }

  double _calculateFatPercentage(FoodItem item) {
    if (item.calories == 0) return 0;
    return (item.fat * 9) / item.calories * 100;
  }

  void _filterFoodItems() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredFoodItems = foodItems;
      } else {
        // Filter based on toggle (searchByTag)
        filteredFoodItems = foodItems.where((item) {
          if (searchByTag) {
            // Search by tag
            return item.tag.toLowerCase().contains(query);
          } else {
            // Search by name
            return item.name.toLowerCase().contains(query);
          }
        }).toList();
        
        // Apply sorting to filtered items
        _sortFilteredItems();
      }
    });
  }

  void _sortFilteredItems() {
    switch (sortBy) {
      case 'protein%':
        filteredFoodItems.sort((a, b) => _calculateProteinPercentage(b).compareTo(_calculateProteinPercentage(a)));
        break;
      case 'carb%':
        filteredFoodItems.sort((a, b) => _calculateCarbPercentage(b).compareTo(_calculateCarbPercentage(a)));
        break;
      case 'fat%':
        filteredFoodItems.sort((a, b) => _calculateFatPercentage(b).compareTo(_calculateFatPercentage(a)));
        break;
    }
  }

  void _clearForm() {
    nameController.clear();
    tagController.clear();
    quantityController.clear();
    proteinController.clear();
    carbohydrateController.clear();
    fatController.clear();
    selectedUnit = 'unit';
    editingItem = null;
    calculatedCalories = '0'; // Reset calculated calories
  }

  void _showAddItemForm() {
    _clearForm();
    setState(() {
      isAddingItem = true;
    });
  }

  void _hideAddItemForm() {
    setState(() {
      isAddingItem = false;
      editingItem = null;
    });
    _clearForm();
  }

  void _editFoodItem(FoodItem item) {
    nameController.text = item.name;
    tagController.text = item.tag;
    
    // Parse unit field to extract quantity and unit
    final unitParts = item.unit.split(' ');
    if (unitParts.length >= 2) {
      quantityController.text = unitParts[0];
      selectedUnit = unitParts[1];
    } else {
      quantityController.text = '1';
      selectedUnit = item.unit;
    }
    
    proteinController.text = item.protein.toString();
    carbohydrateController.text = item.carbohydrate.toString();
    fatController.text = item.fat.toString();
    
    // Update calculated calories for editing
    _updateCaloriesRealTime();
    
    setState(() {
      editingItem = item;
      isAddingItem = true;
    });
  }

  // Calculate calories using the formula: 4*(carb+protein) + 9*fat
  double _calculateCalories(double protein, double carbs, double fat) {
    return (4 * (protein + carbs)) + (9 * fat);
  }

  Future<void> _saveFoodItem() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final protein = double.parse(proteinController.text);
      final carbs = double.parse(carbohydrateController.text);
      final fat = double.parse(fatController.text);
      
      // Calculate calories automatically
      final calculatedCaloriesValue = _calculateCalories(protein, carbs, fat);
      
      // Combine quantity and unit
      final combinedUnit = '${quantityController.text} $selectedUnit';
      
      final foodItem = FoodItem(
        name: nameController.text.trim(),
        tag: tagController.text.trim().isEmpty ? 'General' : tagController.text.trim(),
        unit: combinedUnit,
        calories: calculatedCaloriesValue,
        protein: protein,
        carbohydrate: carbs,
        fat: fat,
      );

      if (editingItem != null) {
        // Update existing item
        await editingItem!.delete();
      }
      
      await HiveService.saveFoodItem(foodItem);
      
      _loadFoodItems();
      _hideAddItemForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editingItem != null ? 'Food item updated!' : 'Food item added!'),
          backgroundColor: Color(0xFF8B7CF6),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving food item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFoodItem(FoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Food Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await item.delete();
        _loadFoodItems();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Food item deleted'),
            backgroundColor: Color(0xFF8B7CF6),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting food item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getCalculatedCalories() {
    try {
      final protein = double.tryParse(proteinController.text) ?? 0;
      final carbs = double.tryParse(carbohydrateController.text) ?? 0;
      final fat = double.tryParse(fatController.text) ?? 0;
      final calories = _calculateCalories(protein, carbs, fat);
      return calories.toStringAsFixed(0);
    } catch (e) {
      return '0';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    tagController.dispose();
    quantityController.dispose();
    proteinController.dispose();
    carbohydrateController.dispose();
    fatController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Your Food Items',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.05,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          if (!isAddingItem)
            IconButton(
              icon: Icon(Icons.add, color: Color(0xFF8B7CF6)),
              onPressed: _showAddItemForm,
            ),
        ],
      ),
      body: Column(
        children: [
          if (isAddingItem) 
            Expanded(
              child: SingleChildScrollView(
                child: _buildAddItemForm(screenWidth, screenHeight),
              ),
            ),
          if (!isAddingItem) ...[
            _buildSearchAndSortBar(screenWidth),
            Expanded(child: _buildFoodItemsList(screenWidth)),
          ],
        ],
      ),
    );
  }

  Widget _buildAddItemForm(double screenWidth, double screenHeight) {
    return Container(
      margin: EdgeInsets.all(screenWidth * 0.04),
      padding: EdgeInsets.all(screenWidth * 0.04),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  editingItem != null ? 'Edit Food Item' : 'Add Food Item',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey),
                  onPressed: _hideAddItemForm,
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            
            // Food Name
            TextFormField(
              controller: nameController,
              style: TextStyle(fontSize: screenWidth * 0.04),
              decoration: InputDecoration(
                labelText: 'Food Name *',
                labelStyle: TextStyle(fontSize: screenWidth * 0.035),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.restaurant, color: Color(0xFF8B7CF6)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter food name';
                }
                return null;
              },
            ),
            SizedBox(height: screenHeight * 0.02),
            
            // Tag (Optional)
            TextFormField(
              controller: tagController,
              style: TextStyle(fontSize: screenWidth * 0.04),
              decoration: InputDecoration(
                labelText: 'Tag (Optional)',
                labelStyle: TextStyle(fontSize: screenWidth * 0.035),
                hintText: 'e.g., Breakfast, Protein, Snack',
                hintStyle: TextStyle(fontSize: screenWidth * 0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.label, color: Color(0xFF8B7CF6)),
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            
            // Quantity and Unit Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: screenWidth * 0.04),
                    decoration: InputDecoration(
                      labelText: 'Quantity *',
                      labelStyle: TextStyle(fontSize: screenWidth * 0.035),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.straighten, color: Color(0xFF8B7CF6)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Numbers only!';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,
                    style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Unit *',
                      labelStyle: TextStyle(fontSize: screenWidth * 0.035),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: unitOptions.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedUnit = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            
            // Nutritional Information Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: proteinController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: screenWidth * 0.04),
                    decoration: InputDecoration(
                      labelText: 'Protein (g) *',
                      labelStyle: TextStyle(fontSize: screenWidth * 0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final parsed = double.tryParse(value);
                      if (parsed == null) return 'Numbers only!';
                      if (parsed < 0) return 'Must be positive';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: TextFormField(
                    controller: carbohydrateController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: screenWidth * 0.04),
                    decoration: InputDecoration(
                      labelText: 'Carbs (g) *',
                      labelStyle: TextStyle(fontSize: screenWidth * 0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final parsed = double.tryParse(value);
                      if (parsed == null) return 'Numbers only!';
                      if (parsed < 0) return 'Must be positive';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: fatController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: screenWidth * 0.04),
                    decoration: InputDecoration(
                      labelText: 'Fat (g) *',
                      labelStyle: TextStyle(fontSize: screenWidth * 0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final parsed = double.tryParse(value);
                      if (parsed == null) return 'Numbers only!';
                      if (parsed < 0) return 'Must be positive';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                // Calories Display (Real-time calculated)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    decoration: BoxDecoration(
                      color: Color(0xFF8B7CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF8B7CF6).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Calories',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: Color(0xFF8B7CF6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          calculatedCalories, // Real-time updated value
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B7CF6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.025),
            
            // Save Button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveFoodItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B7CF6),
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  editingItem != null ? 'Update Food Item' : 'Save Food Item',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
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

  Widget _buildSearchAndSortBar(double screenWidth) {
    return Container(
      margin: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        children: [
          // Search Bar with Toggle
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  style: TextStyle(fontSize: screenWidth * 0.04),
                  decoration: InputDecoration(
                    labelText: 'Search by ${searchByTag ? "tag" : "name"}...',
                    labelStyle: TextStyle(fontSize: screenWidth * 0.035),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF8B7CF6)),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              _filterFoodItems();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              // Search Toggle Button
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF8B7CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF8B7CF6).withOpacity(0.3)),
                ),
                child: IconButton(
                  icon: Icon(
                    searchByTag ? Icons.label : Icons.text_fields,
                    color: Color(0xFF8B7CF6),
                  ),
                  onPressed: () {
                    setState(() {
                      searchByTag = !searchByTag;
                      _filterFoodItems(); // Re-filter with new basis
                    });
                  },
                  tooltip: searchByTag ? 'Search by Tag' : 'Search by Name',
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.02),
          // Sort Dropdown (without name option)
          Row(
            children: [
              Icon(Icons.sort, color: Color(0xFF8B7CF6)),
              SizedBox(width: 8),
              Text(
                'Sort by:',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: sortBy,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 'protein%', child: Text('Protein %')),
                    DropdownMenuItem(value: 'carb%', child: Text('Carb %')),
                    DropdownMenuItem(value: 'fat%', child: Text('Fat %')),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      sortBy = newValue!;
                      _loadFoodItems();
                      _filterFoodItems();
                    });
                  },
                ),
              ),
            ],
          ),
          // Search Toggle Status Indicator
          if (searchController.text.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFF8B7CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Searching by ${searchByTag ? "tag" : "name"}',
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Color(0xFF8B7CF6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodItemsList(double screenWidth) {
    if (filteredFoodItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: screenWidth * 0.2,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              searchController.text.isEmpty ? 'No food items added yet' : 'No food items found',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              searchController.text.isEmpty 
                  ? 'Tap + to add your first food item' 
                  : 'Try a different search term or toggle search type',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      itemCount: filteredFoodItems.length,
      itemBuilder: (context, index) {
        final item = filteredFoodItems[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(screenWidth * 0.04),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                if (item.tag.isNotEmpty && item.tag != 'General')
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF8B7CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.tag,
                      style: TextStyle(
                        fontSize: screenWidth * 0.025,
                        color: Color(0xFF8B7CF6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.unit,
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _getPercentageText(item),
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: Color(0xFF8B7CF6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    _buildNutrientChip('${item.calories.toStringAsFixed(0)} kcal', Colors.orange, screenWidth),
                    _buildNutrientChip('P: ${item.protein.toStringAsFixed(1)}g', Colors.blue, screenWidth),
                    _buildNutrientChip('C: ${item.carbohydrate.toStringAsFixed(1)}g', Colors.green, screenWidth),
                    _buildNutrientChip('F: ${item.fat.toStringAsFixed(1)}g', Colors.purple, screenWidth),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Color(0xFF8B7CF6)),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editFoodItem(item);
                } else if (value == 'delete') {
                  _deleteFoodItem(item);
                }
              },
            ),
          ),
        );
      },
    );
  }

  String _getPercentageText(FoodItem item) {
    switch (sortBy) {
      case 'protein%':
        return '${_calculateProteinPercentage(item).toStringAsFixed(1)}% Protein';
      case 'carb%':
        return '${_calculateCarbPercentage(item).toStringAsFixed(1)}% Carb';
      case 'fat%':
        return '${_calculateFatPercentage(item).toStringAsFixed(1)}% Fat';
      default:
        return '';
    }
  }

  Widget _buildNutrientChip(String label, Color color, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.015,
        vertical: screenWidth * 0.005,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: screenWidth * 0.025,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
