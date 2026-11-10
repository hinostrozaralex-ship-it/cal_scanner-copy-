import 'dart:convert';

import '../../features/calories/domain/entities/food.dart';

class MealRecord {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime dateTime;

  const MealRecord({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.dateTime,
  });

  MealRecord copyWith({
    String? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? dateTime,
  }) {
    return MealRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      dateTime: dateTime ?? this.dateTime,
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
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    return MealRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      dateTime: DateTime.parse(
        (map['dateTime'] ?? map['timestamp']) as String,
      ),
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
      quantity: 100.0,
      timestamp: dateTime,
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
      dateTime: food.timestamp,
    );
  }
}
