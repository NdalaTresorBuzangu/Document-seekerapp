import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offline_storage.dart';

/// Persists the new-request wizard to **SharedPreferences** and mirrors to **Hive**
/// so drafts survive abrupt shutdowns.
class SubmitDraftStore {
  static const _prefsKey = 'newRequestFormDraftJsonV1';

  static Future<void> saveJson(String json) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, json);
    await OfflineStorageService.saveNewRequestFormDraftJson(json);
  }

  static Future<String?> loadJson() async {
    final sp = await SharedPreferences.getInstance();
    final fromPrefs = sp.getString(_prefsKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) return fromPrefs;
    return OfflineStorageService.getNewRequestFormDraftJson();
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_prefsKey);
    await OfflineStorageService.clearNewRequestFormDraftJson();
  }

  static Future<Map<String, dynamic>?> loadMap() async {
    final raw = await loadJson();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
