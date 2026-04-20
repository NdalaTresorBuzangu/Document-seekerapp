import 'package:hive_flutter/hive_flutter.dart';

import 'offline_storage.dart';

/// JWT + profile — backed by Hive like the WasteJustice template (`OfflineStorageService` + `wasteJusticeBox`).
class SessionStore {
  static Future<void> warmUp() async {
    await Hive.initFlutter();
    await Hive.openBox(OfflineStorageService.boxName);
  }

  static Map<String, dynamic>? _creds() {
    final m = OfflineStorageService.getUserCredentials();
    if (m == null) return null;
    return Map<String, dynamic>.from(m);
  }

  static Future<void> saveSession({
    required String token,
    required int userId,
    required String userName,
    required String userEmail,
  }) async {
    await OfflineStorageService.saveUserCredentials(
      userId.toString(),
      token,
      userName: userName,
      userEmail: userEmail,
    );
  }

  static Future<void> clear() async {
    await OfflineStorageService.clearUserCredentials();
  }

  static String? get token => _creds()?['token']?.toString();

  static int? get userId {
    final v = _creds()?['userId'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  static String? get userName => _creds()?['userName']?.toString();

  static String? get userEmail => _creds()?['userEmail']?.toString();

  static Map<String, String> authHeaders() {
    final t = token;
    if (t == null || t.isEmpty) return {};
    return {'Authorization': 'Bearer $t'};
  }
}
