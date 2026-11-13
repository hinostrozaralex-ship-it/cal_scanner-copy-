class FoodIngredient {
  final String id;
  final String name;
  final double quantity;
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double baseCalories;
  final double baseProtein;
  final double baseCarbs;
  final double baseFat;

  const FoodIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    double? servingSize,
    this.servingUnit = 'g',
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
  }) : servingSize = servingSize ?? (quantity > 0 ? quantity : 100.0),
       baseCalories = baseCalories ?? calories,
       baseProtein = baseProtein ?? protein,
       baseCarbs = baseCarbs ?? carbs,
       baseFat = baseFat ?? fat;

  FoodIngredient copyWith({
    String? id,
    String? name,
    double? quantity,
    double? servingSize,
    String? servingUnit,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
  }) {
    return FoodIngredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      baseCalories: baseCalories ?? this.baseCalories,
      baseProtein: baseProtein ?? this.baseProtein,
      baseCarbs: baseCarbs ?? this.baseCarbs,
      baseFat: baseFat ?? this.baseFat,
    );
  }

  FoodIngredient withQuantity(double newQuantity) {
    final safeQty = newQuantity < 0 ? 0.0 : newQuantity;
    final base = servingSize > 0 ? servingSize : 100.0;
    final ratio = safeQty / base;
    return copyWith(
      quantity: safeQty,
      calories: baseCalories * ratio,
      protein: baseProtein * ratio,
      carbs: baseCarbs * ratio,
      fat: baseFat * ratio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'baseCalories': baseCalories,
      'baseProtein': baseProtein,
      'baseCarbs': baseCarbs,
      'baseFat': baseFat,
    };
  }

  factory FoodIngredient.fromMap(Map<String, dynamic> map) {
    final calories = (map['calories'] as num?)?.toDouble() ?? 0.0;
    final protein = (map['protein'] as num?)?.toDouble() ?? 0.0;
    final carbs = (map['carbs'] as num?)?.toDouble() ?? 0.0;
    final fat = (map['fat'] as num?)?.toDouble() ?? 0.0;
    final servingSize =
        (map['servingSize'] as num?)?.toDouble() ??
        (map['serving_size'] as num?)?.toDouble() ??
        (map['quantity'] as num?)?.toDouble() ??
        100.0;
    final quantity = (map['quantity'] as num?)?.toDouble() ?? servingSize;

    return FoodIngredient(
      id: (map['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: (map['name'] as String?) ?? 'Ingredient',
      quantity: quantity,
      servingSize: servingSize > 0 ? servingSize : 100.0,
      servingUnit:
          (map['servingUnit'] ?? map['serving_unit']) as String? ?? 'g',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      baseCalories: (map['baseCalories'] as num?)?.toDouble() ?? calories,
      baseProtein: (map['baseProtein'] as num?)?.toDouble() ?? protein,
      baseCarbs: (map['baseCarbs'] as num?)?.toDouble() ?? carbs,
      baseFat: (map['baseFat'] as num?)?.toDouble() ?? fat,
    );
  }
}

class Food {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double quantity;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isFood;
  final double servingSize;
  final String servingUnit;
  final double baseCalories;
  final double baseProtein;
  final double baseCarbs;
  final double baseFat;
  final String? nonFoodMessage;
  final List<FoodIngredient> ingredients;

  const Food({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.quantity,
    this.imageUrl,
    required this.timestamp,
    this.isFood = true,
    double? servingSize,
    this.servingUnit = 'g',
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
    this.nonFoodMessage,
    this.ingredients = const [],
  }) : servingSize = servingSize ?? (quantity > 0 ? quantity : 100.0),
       baseCalories = baseCalories ?? calories,
       baseProtein = baseProtein ?? protein,
       baseCarbs = baseCarbs ?? carbs,
       baseFat = baseFat ?? fat;

  Food copyWith({
    String? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? quantity,
    String? imageUrl,
    DateTime? timestamp,
    bool? isFood,
    double? servingSize,
    String? servingUnit,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
    String? nonFoodMessage,
    List<FoodIngredient>? ingredients,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isFood: isFood ?? this.isFood,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      baseCalories: baseCalories ?? this.baseCalories,
      baseProtein: baseProtein ?? this.baseProtein,
      baseCarbs: baseCarbs ?? this.baseCarbs,
      baseFat: baseFat ?? this.baseFat,
      nonFoodMessage: nonFoodMessage ?? this.nonFoodMessage,
      ingredients: ingredients ?? this.ingredients,
    );
  }
}

