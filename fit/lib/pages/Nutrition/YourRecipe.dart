import 'package:flutter/material.dart';
import '../../services/hive_service.dart';
import '../../models/recipe.dart';
import '../../models/food_item.dart';

class YourRecipe extends StatefulWidget {
  @override
  _YourRecipeState createState() => _YourRecipeState();
}

class _YourRecipeState extends State<YourRecipe> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  late TextEditingController nameController;
  late TextEditingController tagController;
  late TextEditingController quantityController;
  late TextEditingController searchController;
  
  List<Recipe> recipes = [];
  List<Recipe> filteredRecipes = [];
  List<RecipeIngredient> currentIngredients = [];
  bool isAddingRecipe = false;
  Recipe? editingRecipe;
  String selectedUnit = 'serving';
  String sortBy = 'protein%';
  bool searchByTag = false;
  
  // Nutritional totals for current recipe
  double totalCalories = 0.0;
  double totalProtein = 0.0;
  double totalCarbohydrate = 0.0;
  double totalFat = 0.0;
  
  // Updated units as requested
  final List<String> unitOptions = ['serving', 'gram', 'ml', 'Litre'];
  final List<String> sortOptions = ['protein%', 'carb%', 'fat%'];
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadRecipes();
  }

  void _initializeControllers() {
    nameController = TextEditingController();
    tagController = TextEditingController();
    quantityController = TextEditingController();
    searchController = TextEditingController();
    
    searchController.addListener(_filterRecipes);
  }

  void _loadRecipes() {
    setState(() {
      recipes = HiveService.getAllRecipes();
      _sortRecipes();
      filteredRecipes = recipes;
    });
  }

  void _sortRecipes() {
    switch (sortBy) {
      case 'protein%':
        recipes.sort((a, b) => _calculateProteinPercentage(b).compareTo(_calculateProteinPercentage(a)));
        break;
      case 'carb%':
        recipes.sort((a, b) => _calculateCarbPercentage(b).compareTo(_calculateCarbPercentage(a)));
        break;
      case 'fat%':
        recipes.sort((a, b) => _calculateFatPercentage(b).compareTo(_calculateFatPercentage(a)));
        break;
    }
  }

  double _calculateProteinPercentage(Recipe recipe) {
    if (recipe.totalCalories == 0) return 0;
    return (recipe.totalProtein * 4) / recipe.totalCalories * 100;
  }

  double _calculateCarbPercentage(Recipe recipe) {
    if (recipe.totalCalories == 0) return 0;
    return (recipe.totalCarbohydrate * 4) / recipe.totalCalories * 100;
  }

  double _calculateFatPercentage(Recipe recipe) {
    if (recipe.totalCalories == 0) return 0;
    return (recipe.totalFat * 9) / recipe.totalCalories * 100;
  }

  void _filterRecipes() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredRecipes = recipes;
      } else {
        filteredRecipes = recipes.where((recipe) {
          if (searchByTag) {
            return recipe.tag.toLowerCase().contains(query);
          } else {
            return recipe.name.toLowerCase().contains(query);
          }
        }).toList();
        _sortFilteredRecipes();
      }
    });
  }

  void _sortFilteredRecipes() {
    switch (sortBy) {
      case 'protein%':
        filteredRecipes.sort((a, b) => _calculateProteinPercentage(b).compareTo(_calculateProteinPercentage(a)));
        break;
      case 'carb%':
        filteredRecipes.sort((a, b) => _calculateCarbPercentage(b).compareTo(_calculateCarbPercentage(a)));
        break;
      case 'fat%':
        filteredRecipes.sort((a, b) => _calculateFatPercentage(b).compareTo(_calculateFatPercentage(a)));
        break;
    }
  }

  void _calculateTotals() {
    totalCalories = currentIngredients.fold(0.0, (sum, ingredient) => sum + ingredient.calories);
    totalProtein = currentIngredients.fold(0.0, (sum, ingredient) => sum + ingredient.protein);
    totalCarbohydrate = currentIngredients.fold(0.0, (sum, ingredient) => sum + ingredient.carbohydrate);
    totalFat = currentIngredients.fold(0.0, (sum, ingredient) => sum + ingredient.fat);
  }

  void _clearForm() {
    nameController.clear();
    tagController.clear();
    quantityController.clear();
    currentIngredients.clear();
    selectedUnit = 'serving';
    editingRecipe = null;
    totalCalories = 0.0;
    totalProtein = 0.0;
    totalCarbohydrate = 0.0;
    totalFat = 0.0;
  }

  void _showAddRecipeForm() {
    _clearForm();
    setState(() {
      isAddingRecipe = true;
    });
  }

  void _hideAddRecipeForm() {
    setState(() {
      isAddingRecipe = false;
      editingRecipe = null;
    });
    _clearForm();
  }

  void _editRecipe(Recipe recipe) {
    nameController.text = recipe.name;
    tagController.text = recipe.tag;
    
    // Parse unit field
    final unitParts = recipe.unit.split(' ');
    if (unitParts.length >= 2) {
      quantityController.text = unitParts[0];
      selectedUnit = unitParts[1];
    } else {
      quantityController.text = '1';
      selectedUnit = recipe.unit;
    }
    
    currentIngredients = List.from(recipe.ingredients);
    _calculateTotals();
    
    setState(() {
      editingRecipe = recipe;
      isAddingRecipe = true;
    });
  }

  void _showAddIngredientDialog() {
    final availableFoodItems = HiveService.getAllFoodItems();
    
    if (availableFoodItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No food items available. Add some food items first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _buildAddIngredientDialog(availableFoodItems),
    );
  }

  Widget _buildAddIngredientDialog(List<FoodItem> foodItems) {
    FoodItem? selectedFoodItem;
    TextEditingController ingredientQuantityController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text('Add Ingredient'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Food Item Dropdown
                DropdownButtonFormField<FoodItem>(
                  value: selectedFoodItem,
                  decoration: InputDecoration(
                    labelText: 'Select Food Item',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: foodItems.map((foodItem) {
                    return DropdownMenuItem<FoodItem>(
                      value: foodItem,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            foodItem.name,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${foodItem.unit} - ${foodItem.calories.toStringAsFixed(0)} kcal',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (FoodItem? newValue) {
                    setDialogState(() {
                      selectedFoodItem = newValue;
                    });
                  },
                ),
                SizedBox(height: 16),
                
                // Quantity Input
                TextFormField(
                  controller: ingredientQuantityController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: selectedFoodItem != null ? 'Quantity (${selectedFoodItem!.unit})' : 'Quantity',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (value) => setDialogState(() {}), // Refresh preview
                ),
                
                // Show calculated nutrition if food item selected
                if (selectedFoodItem != null && ingredientQuantityController.text.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF8B7CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('Nutritional Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        _buildNutritionPreview(selectedFoodItem!, ingredientQuantityController.text),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedFoodItem != null && ingredientQuantityController.text.isNotEmpty) {
                  final quantity = double.tryParse(ingredientQuantityController.text);
                  if (quantity != null && quantity > 0) {
                    _addIngredient(selectedFoodItem!, quantity);
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF8B7CF6)),
              child: Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNutritionPreview(FoodItem foodItem, String quantityText) {
    final quantity = double.tryParse(quantityText) ?? 0;
    if (quantity <= 0) return Text('Enter quantity to see preview');
    
    // Calculate nutrition based on quantity ratio
    final baseQuantity = _extractQuantityFromUnit(foodItem.unit);
    final ratio = quantity / baseQuantity;
    
    final calories = foodItem.calories * ratio;
    final protein = foodItem.protein * ratio;
    final carbs = foodItem.carbohydrate * ratio;
    final fat = foodItem.fat * ratio;
    
    return Column(
      children: [
        Text('${calories.toStringAsFixed(0)} kcal'),
        Text('P: ${protein.toStringAsFixed(1)}g | C: ${carbs.toStringAsFixed(1)}g | F: ${fat.toStringAsFixed(1)}g'),
      ],
    );
  }

  double _extractQuantityFromUnit(String unit) {
    RegExp regex = RegExp(r'(\d+(?:\.\d+)?)');
    Match? match = regex.firstMatch(unit);
    return match != null ? double.parse(match.group(1)!) : 1.0;
  }

  void _addIngredient(FoodItem foodItem, double quantity) {
    final baseQuantity = _extractQuantityFromUnit(foodItem.unit);
    final ratio = quantity / baseQuantity;
    
    final ingredient = RecipeIngredient(
      foodItemName: foodItem.name,
      quantity: quantity,
      unit: foodItem.unit,
      calories: foodItem.calories * ratio,
      protein: foodItem.protein * ratio,
      carbohydrate: foodItem.carbohydrate * ratio,
      fat: foodItem.fat * ratio,
    );
    
    setState(() {
      currentIngredients.add(ingredient);
      _calculateTotals();
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      currentIngredients.removeAt(index);
      _calculateTotals();
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (currentIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one ingredient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final combinedUnit = '${quantityController.text} $selectedUnit';
      
      final recipe = Recipe(
        name: nameController.text.trim(),
        tag: tagController.text.trim().isEmpty ? 'General' : tagController.text.trim(),
        unit: combinedUnit,
        ingredients: currentIngredients,
        totalCalories: totalCalories,
        totalProtein: totalProtein,
        totalCarbohydrate: totalCarbohydrate,
        totalFat: totalFat,
      );

      if (editingRecipe != null) {
        await editingRecipe!.delete();
      }
      
      await HiveService.saveRecipe(recipe);
      
      _loadRecipes();
      _hideAddRecipeForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editingRecipe != null ? 'Recipe updated!' : 'Recipe added!'),
          backgroundColor: Color(0xFF8B7CF6),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving recipe: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${recipe.name}"?'),
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
        await recipe.delete();
        _loadRecipes();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe deleted'),
            backgroundColor: Color(0xFF8B7CF6),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    tagController.dispose();
    quantityController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed responsive design for consistent UI across devices
    final screenSize = MediaQuery.of(context).size;
    final baseWidth = 360.0; // Base design width
    final baseHeight = 800.0; // Base design height
    final scaleFactorWidth = screenSize.width / baseWidth;
    final scaleFactorHeight = screenSize.height / baseHeight;
    final scaleFactor = (scaleFactorWidth + scaleFactorHeight) / 2; // Average scale factor
    
    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Your Recipes',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18 * scaleFactor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          if (!isAddingRecipe)
            IconButton(
              icon: Icon(Icons.add, color: Color(0xFF8B7CF6)),
              onPressed: _showAddRecipeForm,
            ),
        ],
      ),
      body: Column(
        children: [
          if (isAddingRecipe) 
            Expanded(
              child: SingleChildScrollView(
                child: _buildAddRecipeForm(scaleFactor),
              ),
            ),
          if (!isAddingRecipe) ...[
            _buildSearchAndSortBar(scaleFactor),
            Expanded(child: _buildRecipesList(scaleFactor)),
          ],
        ],
      ),
    );
  }

  Widget _buildAddRecipeForm(double scaleFactor) {
    return Container(
      margin: EdgeInsets.all(16 * scaleFactor),
      padding: EdgeInsets.all(16 * scaleFactor),
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
                  editingRecipe != null ? 'Edit Recipe' : 'Add Recipe',
                  style: TextStyle(
                    fontSize: 20 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey),
                  onPressed: _hideAddRecipeForm,
                ),
              ],
            ),
            SizedBox(height: 16 * scaleFactor),
            
            // Recipe Name - with error message inside
            TextFormField(
              controller: nameController,
              style: TextStyle(fontSize: 14 * scaleFactor),
              decoration: InputDecoration(
                labelText: 'Recipe Name',
                hintText: 'Required', // Shows "Required" inside when empty
                labelStyle: TextStyle(fontSize: 12 * scaleFactor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.restaurant_menu, color: Color(0xFF8B7CF6)),
                errorStyle: TextStyle(fontSize: 10 * scaleFactor), // Error inside
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            SizedBox(height: 16 * scaleFactor),
            
            // Tag (Optional)
            TextFormField(
              controller: tagController,
              style: TextStyle(fontSize: 14 * scaleFactor),
              decoration: InputDecoration(
                labelText: 'Tag (Optional)',
                labelStyle: TextStyle(fontSize: 12 * scaleFactor),
                hintText: 'e.g., Breakfast, Healthy, Quick',
                hintStyle: TextStyle(fontSize: 11 * scaleFactor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.label, color: Color(0xFF8B7CF6)),
              ),
            ),
            SizedBox(height: 16 * scaleFactor),
            
            // Quantity and Unit Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 14 * scaleFactor),
                    decoration: InputDecoration(
                      labelText: 'Serves',
                      hintText: 'Required', // Shows "Required" inside when empty
                      labelStyle: TextStyle(fontSize: 12 * scaleFactor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.straighten, color: Color(0xFF8B7CF6)),
                      errorStyle: TextStyle(fontSize: 10 * scaleFactor), // Error inside
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
                SizedBox(width: 8 * scaleFactor),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,
                    style: TextStyle(fontSize: 14 * scaleFactor, color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      labelStyle: TextStyle(fontSize: 12 * scaleFactor),
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
            SizedBox(height: 16 * scaleFactor),
            
            // Ingredients Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingredients',
                  style: TextStyle(
                    fontSize: 16 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddIngredientDialog,
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text('Add', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF8B7CF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * scaleFactor),
            
            // Ingredients List
            Container(
              constraints: BoxConstraints(maxHeight: 200 * scaleFactor),
              child: currentIngredients.isEmpty
                  ? Container(
                      padding: EdgeInsets.all(20 * scaleFactor),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          'No ingredients added yet.\nTap "Add" to add ingredients.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12 * scaleFactor,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentIngredients.length,
                      itemBuilder: (context, index) {
                        final ingredient = currentIngredients[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 8 * scaleFactor),
                          padding: EdgeInsets.all(12 * scaleFactor),
                          decoration: BoxDecoration(
                            color: Color(0xFF8B7CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFF8B7CF6).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ingredient.foodItemName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12 * scaleFactor,
                                      ),
                                    ),
                                    Text(
                                      '${ingredient.quantity} ${ingredient.unit.split(' ').length > 1 ? ingredient.unit.split(' ')[1] : 'unit'}',
                                      style: TextStyle(fontSize: 11 * scaleFactor),
                                    ),
                                    Text(
                                      '${ingredient.calories.toStringAsFixed(0)} kcal | P: ${ingredient.protein.toStringAsFixed(1)}g | C: ${ingredient.carbohydrate.toStringAsFixed(1)}g | F: ${ingredient.fat.toStringAsFixed(1)}g',
                                      style: TextStyle(
                                        fontSize: 9 * scaleFactor,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeIngredient(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: 16 * scaleFactor),
            
            Center(
              child : Container(
                padding: EdgeInsets.all(16 * scaleFactor),
                decoration: BoxDecoration(
                  color: Color(0xFF8B7CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF8B7CF6).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Nutrition',
                      style: TextStyle(
                        fontSize: 14 * scaleFactor,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B7CF6),
                      ),
                    ),
                    SizedBox(height: 8 * scaleFactor),
                    Wrap(
                      spacing: 20 * scaleFactor,
                      children: [
                        _buildNutrientTotal('${totalCalories.toStringAsFixed(0)} kcal', Colors.orange, scaleFactor),
                        _buildNutrientTotal('P: ${totalProtein.toStringAsFixed(1)}g', Colors.blue, scaleFactor),
                        _buildNutrientTotal('C: ${totalCarbohydrate.toStringAsFixed(1)}g', Colors.green, scaleFactor),
                        _buildNutrientTotal('F: ${totalFat.toStringAsFixed(1)}g', Colors.purple, scaleFactor),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20 * scaleFactor),
            
            // Save Button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B7CF6),
                  padding: EdgeInsets.symmetric(vertical: 16 * scaleFactor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  editingRecipe != null ? 'Update Recipe' : 'Save Recipe',
                  style: TextStyle(
                    fontSize: 14 * scaleFactor,
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

  Widget _buildNutrientTotal(String label, Color color, double scaleFactor) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * scaleFactor,
        vertical: 4 * scaleFactor,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10 * scaleFactor,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchAndSortBar(double scaleFactor) {
    return Container(
      margin: EdgeInsets.all(16 * scaleFactor),
      child: Column(
        children: [
          // Search Bar with Toggle
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  style: TextStyle(fontSize: 14 * scaleFactor),
                  decoration: InputDecoration(
                    labelText: 'Search by ${searchByTag ? "tag" : "name"}...',
                    labelStyle: TextStyle(fontSize: 12 * scaleFactor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF8B7CF6)),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              _filterRecipes();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              SizedBox(width: 8 * scaleFactor),
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
                      _filterRecipes();
                    });
                  },
                  tooltip: searchByTag ? 'Search by Tag' : 'Search by Name',
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scaleFactor),
          // Sort Dropdown
          Row(
            children: [
              Icon(Icons.sort, color: Color(0xFF8B7CF6)),
              SizedBox(width: 8 * scaleFactor),
              Text(
                'Sort by:',
                style: TextStyle(
                  fontSize: 12 * scaleFactor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8 * scaleFactor),
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
                      _loadRecipes();
                      _filterRecipes();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesList(double scaleFactor) {
    if (filteredRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80 * scaleFactor,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16 * scaleFactor),
            Text(
              searchController.text.isEmpty ? 'No recipes added yet' : 'No recipes found',
              style: TextStyle(
                fontSize: 16 * scaleFactor,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8 * scaleFactor),
            Text(
              searchController.text.isEmpty 
                  ? 'Tap + to create your first recipe' 
                  : 'Try a different search term or toggle search type',
              style: TextStyle(
                fontSize: 12 * scaleFactor,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16 * scaleFactor),
      itemCount: filteredRecipes.length,
      itemBuilder: (context, index) {
        final recipe = filteredRecipes[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12 * scaleFactor),
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
          child: ExpansionTile(
            tilePadding: EdgeInsets.all(16 * scaleFactor),
            childrenPadding: EdgeInsets.all(16 * scaleFactor),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14 * scaleFactor,
                  ),
                ),
                if (recipe.tag.isNotEmpty && recipe.tag != 'General')
                  Container(
                    margin: EdgeInsets.only(top: 4 * scaleFactor),
                    padding: EdgeInsets.symmetric(horizontal: 8 * scaleFactor, vertical: 2 * scaleFactor),
                    decoration: BoxDecoration(
                      color: Color(0xFF8B7CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      recipe.tag,
                      style: TextStyle(
                        fontSize: 9 * scaleFactor,
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
                SizedBox(height: 8 * scaleFactor),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      recipe.unit,
                      style: TextStyle(
                        fontSize: 12 * scaleFactor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _getPercentageText(recipe),
                      style: TextStyle(
                        fontSize: 10 * scaleFactor,
                        color: Color(0xFF8B7CF6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4 * scaleFactor),
                Wrap(
                  spacing: 4 * scaleFactor,
                  children: [
                    _buildNutrientChip('${recipe.totalCalories.toStringAsFixed(0)} kcal', Colors.orange, scaleFactor),
                    _buildNutrientChip('P: ${recipe.totalProtein.toStringAsFixed(1)}g', Colors.blue, scaleFactor),
                    _buildNutrientChip('C: ${recipe.totalCarbohydrate.toStringAsFixed(1)}g', Colors.green, scaleFactor),
                    _buildNutrientChip('F: ${recipe.totalFat.toStringAsFixed(1)}g', Colors.purple, scaleFactor),
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
                  _editRecipe(recipe);
                } else if (value == 'delete') {
                  _deleteRecipe(recipe);
                }
              },
            ),
            children: [
              // Fixed ingredients display
              Container(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingredients:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12 * scaleFactor,
                      ),
                    ),
                    SizedBox(height: 8 * scaleFactor),
                    ...recipe.ingredients.map((ingredient) => Padding(
                      padding: EdgeInsets.only(bottom: 4 * scaleFactor),
                      child: Text(
                        '• ${ingredient.foodItemName} - ${ingredient.quantity} ${ingredient.unit.split(' ').length > 1 ? ingredient.unit.split(' ')[1] : 'unit'}',
                        style: TextStyle(fontSize: 10 * scaleFactor),
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPercentageText(Recipe recipe) {
    switch (sortBy) {
      case 'protein%':
        return '${_calculateProteinPercentage(recipe).toStringAsFixed(1)}% Protein';
      case 'carb%':
        return '${_calculateCarbPercentage(recipe).toStringAsFixed(1)}% Carb';
      case 'fat%':
        return '${_calculateFatPercentage(recipe).toStringAsFixed(1)}% Fat';
      default:
        return '';
    }
  }

  Widget _buildNutrientChip(String label, Color color, double scaleFactor) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6 * scaleFactor,
        vertical: 2 * scaleFactor,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9 * scaleFactor,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
