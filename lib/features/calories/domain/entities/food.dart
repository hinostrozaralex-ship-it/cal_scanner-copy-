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
    );
  }
}

