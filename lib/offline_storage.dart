import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

/// Local persistence (Hive): session, draft form, saved IDs, outbound queues, last-fetched
/// API snapshots (issuers/types, document pack, pre-loss list) for offline use — aligned with the reference template app.
class OfflineStorageService {
  static const String boxName = 'documentSeekerBox';

  static Box get _box => Hive.box(boxName);

  /// Total queued outbound items (document submits + chat + pre-loss), for menus / badges.
  static int get pendingQueueTotalCount =>
      pendingDocumentSubmissionCount +
      getPendingChatSends().length +
      getPendingPrelossUploads().length;

  // --- Auth snapshot (mirrors template `userCredentials`) ---
  static Future<void> saveUserCredentials(
    String userId,
    String token, {
    String? userName,
    String? userEmail,
  }) async {
    final map = <String, dynamic>{'userId': userId, 'token': token};
    if (userName != null && userName.trim().isNotEmpty) {
      map['userName'] = userName.trim();
    }
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      map['userEmail'] = userEmail.trim();
    }
    await _box.put('userCredentials', map);
  }

  static Map? getUserCredentials() {
    return _box.get('userCredentials') as Map?;
  }

  static Future<void> clearUserCredentials() async {
    await _box.delete('userCredentials');
  }

  // --- Pending document request (same idea as template `pendingCollectionSubmissions`) ---
  static const String _pendingDocsKey = 'pendingDocumentSubmissions';

  static List<Map<String, dynamic>> getPendingDocumentSubmissions() {
    final raw = _box.get(_pendingDocsKey, defaultValue: <dynamic>[]);
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static Future<void> enqueuePendingDocumentSubmission(Map<String, dynamic> item) async {
    final list = getPendingDocumentSubmissions();
    list.add(item);
    await _box.put(_pendingDocsKey, list);
  }

  static Future<void> removePendingDocumentSubmissionAt(int index) async {
    final list = getPendingDocumentSubmissions();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await _box.put(_pendingDocsKey, list);
    }
  }

  static int get pendingDocumentSubmissionCount =>
      getPendingDocumentSubmissions().length;

  // --- Pending chat sends (local queue when offline) ---
  static const String _pendingChatKey = 'pendingChatSends';

  static List<Map<String, dynamic>> getPendingChatSends() {
    final raw = _box.get(_pendingChatKey, defaultValue: <dynamic>[]);
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static Future<void> enqueuePendingChatSend(Map<String, dynamic> item) async {
    final list = getPendingChatSends();
    list.add(item);
    await _box.put(_pendingChatKey, list);
  }

  static Future<void> removePendingChatSendAt(int index) async {
    final list = getPendingChatSends();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await _box.put(_pendingChatKey, list);
    }
  }

  // --- Pending pre-loss uploads ---
  static const String _pendingPrelossKey = 'pendingPrelossUploads';

  static List<Map<String, dynamic>> getPendingPrelossUploads() {
    final raw = _box.get(_pendingPrelossKey, defaultValue: <dynamic>[]);
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static Future<void> enqueuePendingPrelossUpload(Map<String, dynamic> item) async {
    final list = getPendingPrelossUploads();
    list.add(item);
    await _box.put(_pendingPrelossKey, list);
  }

  static Future<void> removePendingPrelossUploadAt(int index) async {
    final list = getPendingPrelossUploads();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await _box.put(_pendingPrelossKey, list);
    }
  }

  // --- Last successful document list cache (read-only when offline UI hint) ---
  static const String _cachedDocsKey = 'cachedDocumentsJson';

  static Future<void> saveCachedDocumentsJson(String json) async {
    await _box.put(_cachedDocsKey, json);
    await _box.put('cachedDocumentsAt', DateTime.now().toIso8601String());
  }

  static String? getCachedDocumentsJson() => _box.get(_cachedDocsKey) as String?;

  static String? getCachedDocumentsAt() => _box.get('cachedDocumentsAt') as String?;

  // --- Saved document IDs (same idea as web localStorage `documentIDs`) ---
  static const String _savedDocumentIdsKey = 'savedDocumentIds';

  static List<Map<String, dynamic>> getSavedDocumentIds() {
    final raw = _box.get(_savedDocumentIdsKey, defaultValue: <dynamic>[]);
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static Future<void> addSavedDocumentId({
    required String documentId,
    String? description,
    String? createdAtIso,
  }) async {
    final id = documentId.trim();
    if (id.isEmpty) return;
    final list = getSavedDocumentIds();
    list.removeWhere((e) => e['id']?.toString() == id);
    list.insert(0, <String, dynamic>{
      'id': id,
      'description': (description ?? '').trim(),
      'date': createdAtIso ?? DateTime.now().toIso8601String(),
    });
    await _box.put(_savedDocumentIdsKey, list);
  }

  static Future<void> clearSavedDocumentIds() async {
    await _box.delete(_savedDocumentIdsKey);
  }

  /// JSON snapshot of the new-request form (Hive mirror; SharedPreferences holds the same payload).
  static const String _newRequestDraftKey = 'newRequestFormDraftJsonV1';

  static Future<void> saveNewRequestFormDraftJson(String json) async {
    await _box.put(_newRequestDraftKey, json);
  }

  static String? getNewRequestFormDraftJson() => _box.get(_newRequestDraftKey) as String?;

  static Future<void> clearNewRequestFormDraftJson() async {
    await _box.delete(_newRequestDraftKey);
  }

  // --- Cached API meta (issuers / types) for offline new-request UI ---
  static const String _cachedIssuersKey = 'cachedIssuersJsonV1';
  static const String _cachedTypesKey = 'cachedDocumentTypesJsonV1';
  static const String _cachedMetaAtKey = 'cachedMetaAtIso';

  static Future<void> saveCachedMetaSnapshot({
    required String issuersJson,
    required String typesJson,
  }) async {
    await _box.put(_cachedIssuersKey, issuersJson);
    await _box.put(_cachedTypesKey, typesJson);
    await _box.put(_cachedMetaAtKey, DateTime.now().toIso8601String());
  }

  static String? getCachedIssuersJson() => _box.get(_cachedIssuersKey) as String?;

  static String? getCachedTypesJson() => _box.get(_cachedTypesKey) as String?;

  static String? getCachedMetaAtIso() => _box.get(_cachedMetaAtKey) as String?;

  // --- Cached pre-loss list (read-only when offline) ---
  static const String _cachedPrelossKey = 'cachedPrelossListJsonV1';

  static Future<void> saveCachedPrelossListJson(String json) async {
    await _box.put(_cachedPrelossKey, json);
    await _box.put('cachedPrelossAtIso', DateTime.now().toIso8601String());
  }

  static String? getCachedPrelossListJson() => _box.get(_cachedPrelossKey) as String?;

  static String? getCachedPrelossAtIso() => _box.get('cachedPrelossAtIso') as String?;

  // --- Local bytes for pre-loss items uploaded on this device (so View works even if server path differs) ---
  static const String _prelossLocalPrefix = 'prelossLocalBytesV1_';
  static const int _prelossLocalMaxBytes = 12 * 1024 * 1024;

  static Future<void> cachePrelossLocalBytes(int prelossId, Uint8List bytes) async {
    if (prelossId <= 0 || bytes.isEmpty || bytes.length > _prelossLocalMaxBytes) return;
    await _box.put('$_prelossLocalPrefix$prelossId', bytes);
  }

  static Uint8List? getPrelossLocalBytes(int prelossId) {
    if (prelossId <= 0) return null;
    final v = _box.get('$_prelossLocalPrefix$prelossId');
    if (v is Uint8List) return v;
    if (v is List) {
      try {
        return Uint8List.fromList(v.cast<int>());
      } catch (_) {}
    }
    return null;
  }

  static Future<void> removePrelossLocalBytes(int prelossId) async {
    await _box.delete('$_prelossLocalPrefix$prelossId');
  }
}
