import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_record.dart';
import '../models/user_profile.dart';

export '../models/meal_record.dart';
export '../models/user_profile.dart';

class LocalStorageService {
  static const String _userProfileKey = 'user_profile';
  static const String _mealsKey = 'meal_records';
  static const String _legacyApiKey = 'gemini_api_key';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  // ─── UserProfile ──────────────────────────────────────────────────────────

  Future<void> saveUserProfile(UserProfile profile) async {
    await _prefs.setString(_userProfileKey, profile.toJson());

    final trimmedKey = profile.apiKey?.trim() ?? '';
    if (trimmedKey.isNotEmpty) {
      await _prefs.setString(_legacyApiKey, trimmedKey);
    } else {
      await _prefs.remove(_legacyApiKey);
    }
  }

  Future<UserProfile?> getUserProfile() async {
    final raw = _prefs.getString(_userProfileKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return UserProfile.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  bool isUserOnboardedSync() {
    final raw = _prefs.getString(_userProfileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final profile = UserProfile.fromJson(raw);
        return profile.isOnboarded;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  // ─── API Key Resolution (UserProfile.apiKey -> .env fallback) ─────────────

  Future<String?> getApiKey() async {
    final profile = await getUserProfile();
    final profileKey = profile?.apiKey?.trim();
    if (profileKey != null && profileKey.isNotEmpty) {
      return profileKey;
    }

    final legacyKey = _prefs.getString(_legacyApiKey)?.trim();
    if (legacyKey != null && legacyKey.isNotEmpty) {
      return legacyKey;
    }

    try {
      final envKey = dotenv.env['GEMINI_API_KEY']?.trim();
      if (envKey != null &&
          envKey.isNotEmpty &&
          envKey != 'tu_api_key_aqui' &&
          envKey != 'your_api_key_here') {
        return envKey;
      }
    } catch (_) {
      // dotenv may not be initialized
    }

    return null;
  }

  Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(_legacyApiKey);
    } else {
      await _prefs.setString(_legacyApiKey, trimmed);
    }

    final existing = await getUserProfile();
    final updated = (existing ??
            const UserProfile(
              name: '',
              age: 25,
              weight: 70.0,
              height: 170.0,
              unitSystem: 'metric',
              isOnboarded: false,
            ))
        .copyWith(apiKey: trimmed);
    await _prefs.setString(_userProfileKey, updated.toJson());
  }

  // ─── MealRecord History ───────────────────────────────────────────────────

  Future<List<MealRecord>> _getAllMeals() async {
    final raw = _prefs.getString(_mealsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((item) => MealRecord.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMeal(MealRecord meal) async {
    final meals = await _getAllMeals();
    final existingIndex = meals.indexWhere((m) => m.id == meal.id);
    if (existingIndex >= 0) {
      meals[existingIndex] = meal;
    } else {
      meals.add(meal);
    }

    final serialized = jsonEncode(meals.map((m) => m.toMap()).toList());
    await _prefs.setString(_mealsKey, serialized);
  }

  Future<void> updateMeal(MealRecord meal) async {
    await saveMeal(meal);
  }

  Future<List<MealRecord>> getMealsByDate(DateTime date) async {
    final meals = await _getAllMeals();
    return meals.where((meal) {
      return meal.dateTime.year == date.year &&
          meal.dateTime.month == date.month &&
          meal.dateTime.day == date.day;
    }).toList();
  }

  Future<void> deleteMeal(String id) async {
    final meals = await _getAllMeals();
    meals.removeWhere((meal) => meal.id == id);
    final serialized = jsonEncode(meals.map((m) => m.toMap()).toList());
    await _prefs.setString(_mealsKey, serialized);
  }
}
