import '../../domain/entities/food.dart';

class FoodModel {
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

  const FoodModel({
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

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    final calories = (json['calories'] as num?)?.toDouble() ?? 0.0;
    final protein = (json['protein'] as num?)?.toDouble() ?? 0.0;
    final carbs = (json['carbs'] as num?)?.toDouble() ?? 0.0;
    final fat = (json['fat'] as num?)?.toDouble() ?? 0.0;
    final quantity = (json['quantity'] as num?)?.toDouble() ?? 100.0;
    final servingSize =
        (json['servingSize'] as num?)?.toDouble() ??
        (json['serving_size'] as num?)?.toDouble() ??
        (quantity > 0 ? quantity : 100.0);

    final rawIngredients = json['ingredients'];
    final ingredients = rawIngredients is List
        ? rawIngredients
              .whereType<Map>()
              .map((m) => FoodIngredient.fromMap(Map<String, dynamic>.from(m)))
              .toList()
        : const <FoodIngredient>[];

    return FoodModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      quantity: quantity,
      imageUrl: json['imageUrl'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFood: (json['isFood'] ?? json['is_food']) as bool? ?? true,
      servingSize: servingSize,
      servingUnit:
          (json['servingUnit'] ?? json['serving_unit']) as String? ?? 'g',
      baseCalories: (json['baseCalories'] as num?)?.toDouble() ?? calories,
      baseProtein: (json['baseProtein'] as num?)?.toDouble() ?? protein,
      baseCarbs: (json['baseCarbs'] as num?)?.toDouble() ?? carbs,
      baseFat: (json['baseFat'] as num?)?.toDouble() ?? fat,
      nonFoodMessage:
          (json['nonFoodMessage'] ?? json['non_food_message']) as String?,
      ingredients: ingredients,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'isFood': isFood,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'baseCalories': baseCalories,
      'baseProtein': baseProtein,
      'baseCarbs': baseCarbs,
      'baseFat': baseFat,
      'nonFoodMessage': nonFoodMessage,
      'ingredients': ingredients.map((e) => e.toMap()).toList(),
    };
  }

  Food toDomain() {
    return Food(
      id: id,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      quantity: quantity,
      imageUrl: imageUrl,
      timestamp: timestamp,
      isFood: isFood,
      servingSize: servingSize,
      servingUnit: servingUnit,
      baseCalories: baseCalories,
      baseProtein: baseProtein,
      baseCarbs: baseCarbs,
      baseFat: baseFat,
      nonFoodMessage: nonFoodMessage,
      ingredients: ingredients,
    );
  }

  factory FoodModel.fromDomain(Food food) {
    return FoodModel(
      id: food.id,
      name: food.name,
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      quantity: food.quantity,
      imageUrl: food.imageUrl,
      timestamp: food.timestamp,
      isFood: food.isFood,
      servingSize: food.servingSize,
      servingUnit: food.servingUnit,
      baseCalories: food.baseCalories,
      baseProtein: food.baseProtein,
      baseCarbs: food.baseCarbs,
      baseFat: food.baseFat,
      nonFoodMessage: food.nonFoodMessage,
      ingredients: food.ingredients,
    );
  }
}

