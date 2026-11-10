import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage_service.dart';

class ApiKeyStorage {
  final LocalStorageService _localStorage;

  ApiKeyStorage(SharedPreferences prefs)
      : _localStorage = LocalStorageService(prefs);

  Future<String?> getApiKey() => _localStorage.getApiKey();

  Future<void> saveApiKey(String key) => _localStorage.saveApiKey(key);
}
