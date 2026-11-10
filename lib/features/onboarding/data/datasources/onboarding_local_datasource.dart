import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../models/user_data_model.dart';

class OnboardingLocalDataSource {
  static const String _userDataKey = 'userData';
  static const String _onboardingCompleteKey = 'onboarding_complete';

  final SharedPreferences _prefs;
  final LocalStorageService _localStorage;

  OnboardingLocalDataSource(this._prefs)
      : _localStorage = LocalStorageService(_prefs);

  Future<void> saveUserData(UserDataModel userData) async {
    await _prefs.setString(_userDataKey, jsonEncode(userData.toJson()));

    final existingProfile = await _localStorage.getUserProfile();
    final updatedProfile = (existingProfile ??
            UserProfile(
              name: '',
              age: userData.age,
              weight: userData.weight,
              height: userData.heightCm,
              unitSystem: 'metric',
              isOnboarded: _prefs.getBool(_onboardingCompleteKey) ?? false,
            ))
        .copyWith(
      age: userData.age,
      weight: userData.weight,
      height: userData.heightCm,
    );
    await _localStorage.saveUserProfile(updatedProfile);
  }

  Future<UserDataModel?> getUserData() async {
    final raw = _prefs.getString(_userDataKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return UserDataModel.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<bool> isOnboardingComplete() async {
    final profile = await _localStorage.getUserProfile();
    if (profile != null && profile.isOnboarded) {
      return true;
    }
    return _prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_onboardingCompleteKey, value);
    final existingProfile = await _localStorage.getUserProfile();
    if (existingProfile != null) {
      await _localStorage.saveUserProfile(
        existingProfile.copyWith(isOnboarded: value),
      );
    }
  }
}
