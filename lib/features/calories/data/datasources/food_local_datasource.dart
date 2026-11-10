import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../models/food_model.dart';

class FoodLocalDataSource {
  final SharedPreferences _prefs;
  final LocalStorageService _localStorage;

  FoodLocalDataSource(this._prefs)
      : _localStorage = LocalStorageService(_prefs);

  String _keyForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return 'food_log_${day.toIso8601String().split('T')[0]}';
  }

  Future<List<FoodModel>> getDailyFoodLog(DateTime date) async {
    final records = await _localStorage.getMealsByDate(date);
    if (records.isNotEmpty) {
      return records
          .map((r) => FoodModel.fromDomain(r.toFood()))
          .toList();
    }

    final key = _keyForDate(date);
    final stored = _prefs.getString(key);
    if (stored == null) return [];
    final decoded = jsonDecode(stored);
    if (decoded is! List) return [];
    final legacyItems = decoded
        .whereType<Map>()
        .map((m) => FoodModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    for (final item in legacyItems) {
      await _localStorage.saveMeal(MealRecord.fromFood(item.toDomain()));
    }
    return legacyItems;
  }

  Future<void> setDailyFoodLog(DateTime date, List<FoodModel> items) async {
    final key = _keyForDate(date);
    await _prefs.setString(
      key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );

    final existingForDate = await _localStorage.getMealsByDate(date);
    final newIds = items.map((e) => e.id).toSet();
    for (final old in existingForDate) {
      if (!newIds.contains(old.id)) {
        await _localStorage.deleteMeal(old.id);
      }
    }
    for (final item in items) {
      await _localStorage.saveMeal(MealRecord.fromFood(item.toDomain()));
    }
  }
}
