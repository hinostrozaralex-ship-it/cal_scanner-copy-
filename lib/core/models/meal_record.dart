import 'dart:convert';

import '../../features/calories/domain/entities/food.dart';

class MealRecord {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double quantity;
  final String? imageUrl;
  final DateTime dateTime;
  final bool isFood;
  final double servingSize;
  final String servingUnit;
  final double baseCalories;
  final double baseProtein;
  final double baseCarbs;
  final double baseFat;
  final String? nonFoodMessage;

  const MealRecord({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.quantity = 100.0,
    this.imageUrl,
    required this.dateTime,
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

  MealRecord copyWith({
    String? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? quantity,
    String? imageUrl,
    DateTime? dateTime,
    bool? isFood,
    double? servingSize,
    String? servingUnit,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
    String? nonFoodMessage,
  }) {
    return MealRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      dateTime: dateTime ?? this.dateTime,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'quantity': quantity,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'dateTime': dateTime.toIso8601String(),
      'isFood': isFood,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'baseCalories': baseCalories,
      'baseProtein': baseProtein,
      'baseCarbs': baseCarbs,
      'baseFat': baseFat,
      if (nonFoodMessage != null) 'nonFoodMessage': nonFoodMessage,
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    final calories = (map['calories'] as num?)?.toDouble() ?? 0.0;
    final protein = (map['protein'] as num?)?.toDouble() ?? 0.0;
    final carbs = (map['carbs'] as num?)?.toDouble() ?? 0.0;
    final fat = (map['fat'] as num?)?.toDouble() ?? 0.0;
    final quantity = (map['quantity'] as num?)?.toDouble() ?? 100.0;
    final servingSize =
        (map['servingSize'] as num?)?.toDouble() ??
        (map['serving_size'] as num?)?.toDouble() ??
        (quantity > 0 ? quantity : 100.0);

    return MealRecord(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      quantity: quantity,
      imageUrl: map['imageUrl'] as String?,
      dateTime: DateTime.parse(
        (map['dateTime'] ?? map['timestamp']) as String,
      ),
      isFood: (map['isFood'] ?? map['is_food']) as bool? ?? true,
      servingSize: servingSize,
      servingUnit:
          (map['servingUnit'] ?? map['serving_unit']) as String? ?? 'g',
      baseCalories: (map['baseCalories'] as num?)?.toDouble() ?? calories,
      baseProtein: (map['baseProtein'] as num?)?.toDouble() ?? protein,
      baseCarbs: (map['baseCarbs'] as num?)?.toDouble() ?? carbs,
      baseFat: (map['baseFat'] as num?)?.toDouble() ?? fat,
      nonFoodMessage:
          (map['nonFoodMessage'] ?? map['non_food_message']) as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MealRecord.fromJson(dynamic source) {
    if (source is String) {
      return MealRecord.fromMap(
        Map<String, dynamic>.from(jsonDecode(source) as Map),
      );
    }
    if (source is Map) {
      return MealRecord.fromMap(Map<String, dynamic>.from(source));
    }
    throw ArgumentError('Invalid source for MealRecord.fromJson: $source');
  }

  Food toFood() {
    return Food(
      id: id,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      quantity: quantity,
      imageUrl: imageUrl,
      timestamp: dateTime,
      isFood: isFood,
      servingSize: servingSize,
      servingUnit: servingUnit,
      baseCalories: baseCalories,
      baseProtein: baseProtein,
      baseCarbs: baseCarbs,
      baseFat: baseFat,
      nonFoodMessage: nonFoodMessage,
    );
  }

  factory MealRecord.fromFood(Food food) {
    return MealRecord(
      id: food.id,
      name: food.name,
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      quantity: food.quantity,
      imageUrl: food.imageUrl,
      dateTime: food.timestamp,
      isFood: food.isFood,
      servingSize: food.servingSize,
      servingUnit: food.servingUnit,
      baseCalories: food.baseCalories,
      baseProtein: food.baseProtein,
      baseCarbs: food.baseCarbs,
      baseFat: food.baseFat,
      nonFoodMessage: food.nonFoodMessage,
    );
  }
}
