import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's own TfNSW API key on-device only, via the platform's
/// local preferences storage. Nothing here ever leaves the device except
/// in direct requests to api.transport.nsw.gov.au.
class SettingsStore {
  static const _apiKeyPref = 'tfnsw_api_key';
  static const _includeSchoolBusesPref = 'include_school_buses';
  static const _hasSeenSchoolBusTipPref = 'has_seen_school_bus_tip';

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

  /// Whether school bus services should be included alongside regular
  /// public transport. Defaults to false — most users aren't school
  /// students and don't want school services cluttering their list.
  Future<bool> getIncludeSchoolBuses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_includeSchoolBusesPref) ?? false;
  }

  Future<void> setIncludeSchoolBuses(bool include) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_includeSchoolBusesPref, include);
  }

  /// Whether the one-time explainer bubble for the school bus button has
  /// already been shown and dismissed.
  Future<bool> getHasSeenSchoolBusTip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenSchoolBusTipPref) ?? false;
  }

  Future<void> setHasSeenSchoolBusTip(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenSchoolBusTipPref, seen);
  }
}