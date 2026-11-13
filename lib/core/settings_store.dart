import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's own TfNSW API key on-device only, via the platform's
/// local preferences storage. Nothing here ever leaves the device except
/// in direct requests to api.transport.nsw.gov.au.
class SettingsStore {
  static const _apiKeyPref = 'tfnsw_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPref);
  }
}
