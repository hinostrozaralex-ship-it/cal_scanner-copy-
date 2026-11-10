import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyStorage {
  static const String _storageKey = 'gemini_api_key';

  final SharedPreferences _prefs;

  ApiKeyStorage(this._prefs);

  Future<String?> getApiKey() async {
    final savedKey = _prefs.getString(_storageKey)?.trim();
    if (savedKey != null && savedKey.isNotEmpty) {
      return savedKey;
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
      // dotenv may not be initialized in all environments
    }

    return null;
  }

  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(_storageKey);
    } else {
      await _prefs.setString(_storageKey, trimmed);
    }
  }
}
