import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'offline_queue_files.dart';
import 'offline_storage.dart';

/// Flushes Hive-backed queues when the device is online — same idea as WasteJustice `PendingSubmissionSync`
/// (no server/database changes; uses existing REST endpoints).
class PendingSync {
  static bool isLikelyNetworkFailure(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    if (e is HandshakeException || e is TlsException) return true;
    if (e is http.ClientException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('socket') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused') ||
        s.contains('network is unreachable') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('network error');
  }

  /// Returns how many items were successfully sent across all queues.
  static Future<int> flushAll() async {
    var total = 0;
    total += await _flushChat();
    total += await _flushPreloss();
    total += await _flushDocuments();
    return total;
  }

  static Future<int> _flushChat() async {
    var n = 0;
    while (true) {
      final list = OfflineStorageService.getPendingChatSends();
      if (list.isEmpty) break;
      final item = list.first;
      try {
        final docId = item['documentID']?.toString() ?? '';
        final msg = item['message']?.toString() ?? '';
        if (docId.isEmpty || msg.isEmpty) {
          await OfflineStorageService.removePendingChatSendAt(0);
          continue;
        }
        await ApiService.sendChatMessage(docId, msg);
        await OfflineStorageService.removePendingChatSendAt(0);
        n++;
      } catch (_) {
        break;
      }
    }
    return n;
  }

  static Future<int> _flushPreloss() async {
    if (kIsWeb) return 0;
    var n = 0;
    while (true) {
      final list = OfflineStorageService.getPendingPrelossUploads();
      if (list.isEmpty) break;
      final item = list.first;
      try {
        final title = item['title']?.toString() ?? '';
        final path = item['localFilePath']?.toString() ?? '';
        if (title.isEmpty || path.isEmpty) {
          await OfflineStorageService.removePendingPrelossUploadAt(0);
          continue;
        }
        final f = File(path);
        if (!await f.exists()) {
          await OfflineStorageService.removePendingPrelossUploadAt(0);
          continue;
        }
        final newId = await ApiService.uploadPreloss(title: title, file: f);
        if (newId != null) {
          try {
            final b = await f.readAsBytes();
            await OfflineStorageService.cachePrelossLocalBytes(newId, b);
          } catch (_) {}
        }
        await OfflineStorageService.removePendingPrelossUploadAt(0);
        n++;
      } catch (_) {
        break;
      }
    }
    return n;
  }

  static Future<int> _flushDocuments() async {
    if (kIsWeb) return 0;
    var n = 0;
    while (true) {
      final list = OfflineStorageService.getPendingDocumentSubmissions();
      if (list.isEmpty) break;
      final item = list.first;
      try {
        final issuer = item['issuerUserId'];
        final type = item['typeId'];
        final issuerId = issuer is int ? issuer : int.tryParse(issuer.toString()) ?? 0;
        final typeId = type is int ? type : int.tryParse(type.toString()) ?? 0;
        final desc = item['description']?.toString() ?? '';
        final loc = item['location']?.toString() ?? '';
        final paymentRef = item['paymentReference']?.toString();
        File? file;
        final p = item['localAttachmentPath']?.toString();
        if (p != null && p.isNotEmpty) {
          final f = File(p);
          if (await f.exists()) {
            file = f;
          }
        }
        await ApiService.submitDocument(
          issuerUserId: issuerId,
          typeId: typeId,
          description: desc,
          location: loc,
          attachment: file,
          paymentReference: paymentRef,
        );
        await OfflineStorageService.removePendingDocumentSubmissionAt(0);
        n++;
      } catch (_) {
        break;
      }
    }
    return n;
  }

  /// Call after a successful `fetchMyDocuments` to allow offline viewing of last list (JSON string).
  static Future<void> cacheDocumentsList(List<Map<String, dynamic>> docs) async {
    try {
      await OfflineStorageService.saveCachedDocumentsJson(json.encode(docs));
    } catch (_) {}
  }

  static List<Map<String, dynamic>>? readCachedDocumentsList() {
    final raw = OfflineStorageService.getCachedDocumentsJson();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return null;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> cachePrelossList(List<Map<String, dynamic>> items) async {
    try {
      await OfflineStorageService.saveCachedPrelossListJson(json.encode(items));
    } catch (_) {}
  }

  static List<Map<String, dynamic>>? readCachedPrelossList() {
    final raw = OfflineStorageService.getCachedPrelossListJson();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return null;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> enqueueDocumentSubmission({
    required int issuerUserId,
    required int typeId,
    required String description,
    required String location,
    String? localAttachmentPath,
    String? paymentReference,
  }) async {
    String? storedPath;
    final rawPath = localAttachmentPath;
    if (!kIsWeb && rawPath != null && rawPath.isNotEmpty) {
      storedPath = await OfflineQueueFiles.persistForSyncQueue(
        sourcePath: rawPath,
        namespace: 'document_submit',
      );
    }
    await OfflineStorageService.enqueuePendingDocumentSubmission({
      'issuerUserId': issuerUserId,
      'typeId': typeId,
      'description': description,
      'location': location,
      if (paymentReference != null && paymentReference.isNotEmpty)
        'paymentReference': paymentReference,
      if (storedPath != null && storedPath.isNotEmpty)
        'localAttachmentPath': storedPath,
    });
  }

  static Future<void> enqueueChatSend({
    required String documentId,
    required String message,
  }) async {
    await OfflineStorageService.enqueuePendingChatSend({
      'documentID': documentId,
      'message': message,
    });
  }

  static Future<void> enqueuePrelossUpload({
    required String title,
    required String localFilePath,
  }) async {
    final stored = kIsWeb
        ? localFilePath
        : await OfflineQueueFiles.persistForSyncQueue(
            sourcePath: localFilePath,
            namespace: 'preloss',
          );
    await OfflineStorageService.enqueuePendingPrelossUpload({
      'title': title,
      'localFilePath': stored,
    });
  }
}
