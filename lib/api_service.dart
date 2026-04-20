import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'api_config.dart';
import 'session_store.dart';

/// HTTP + JSON layer aligned with WasteJustice [`fluutter app/lib/api_service.dart`]: [_decodeJsonResponse], [_get], [_post].
class ApiService {
  static Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json',
        ...SessionStore.authHeaders(),
      };

  /// Strip BOM; trim leading space/newlines so `<br />` HTML is detected even after whitespace.
  static String _leadingTrimBody(String body) {
    return body.replaceFirst(RegExp(r'^\uFEFF'), '').trimLeft();
  }

  /// If PHP printed notices before JSON, recover the first `{…}` object when possible.
  static Map<String, dynamic>? _tryDecodeJsonMap(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    final i = trimmed.indexOf('{');
    if (i <= 0) return null;
    try {
      final decoded = json.decode(trimmed.substring(i));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic> _decodeJsonResponse(
    http.Response res, {
    String? requestUrl,
  }) {
    final urlHint = requestUrl != null ? ' URL: $requestUrl' : '';
    final raw = res.body.trim();
    if (raw.isEmpty) {
      throw Exception(
        'Empty server response (HTTP ${res.statusCode}).$urlHint '
        'Usually a PHP fatal on the host — upload the full `api` folder and check server error logs. '
        'baseUrl=${ApiConfig.baseUrl}',
      );
    }
    if (res.statusCode == 404) {
      final probe = _leadingTrimBody(res.body);
      final probeLower = probe.toLowerCase();
      if (!probe.startsWith('<') &&
          !probeLower.contains('<!doctype') &&
          !probeLower.contains('<html')) {
        final decoded404 = _tryDecodeJsonMap(res.body);
        if (decoded404 != null && decoded404.containsKey('success')) {
          return decoded404;
        }
      }
      throw Exception(
        'HTTP 404 — file not found.$urlHint '
        'This build expects: ${ApiConfig.auth('register.php')}. '
        'If you still see "Doumentseekerflutterapp" in an error, uninstall the app and install the latest APK (version 1.0.1+2).',
      );
    }
    final lead = _leadingTrimBody(res.body);
    final lower = lead.toLowerCase();
    if (lead.startsWith('<') ||
        lower.contains('<!doctype') ||
        lower.contains('<html') ||
        lower.contains('<br')) {
      throw Exception(
        'HTTP ${res.statusCode}: server returned HTML instead of JSON (often a PHP warning on the host).$urlHint '
        'baseUrl=${ApiConfig.baseUrl} — redeploy `api/config/database.php` (display_errors off) and check server error logs.',
      );
    }
    final decoded = _tryDecodeJsonMap(res.body);
    if (decoded != null) {
      return decoded;
    }
    final preview = raw.length > 240 ? '${raw.substring(0, 240)}…' : raw;
    throw Exception(
      'Invalid JSON from server (HTTP ${res.statusCode}).$urlHint Body: $preview',
    );
  }

  static Map<String, dynamic> _decodeAnyJson(
    http.Response res, {
    String? requestUrl,
  }) {
    final urlHint = requestUrl != null ? ' URL: $requestUrl' : '';
    final raw = res.body.trim();
    if (raw.isEmpty) {
      throw Exception('Empty server response (HTTP ${res.statusCode}).$urlHint');
    }
    final lead = _leadingTrimBody(res.body);
    final lower = lead.toLowerCase();
    if (lead.startsWith('<') ||
        lower.contains('<!doctype') ||
        lower.contains('<html') ||
        lower.contains('<br')) {
      throw Exception(
        'HTTP ${res.statusCode}: server returned HTML instead of JSON.$urlHint',
      );
    }
    final decoded = _tryDecodeJsonMap(res.body);
    if (decoded != null) {
      return decoded;
    }
    throw Exception('Invalid JSON payload (expected object).$urlHint');
  }

  static Future<Map<String, dynamic>> _get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final res = await http.get(Uri.parse(url), headers: headers);
    final body = _decodeJsonResponse(res, requestUrl: url);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Request failed');
    }
    return body;
  }

  static Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> payload, {
    Map<String, String>? headers,
  }) async {
    final res = await http.post(
      Uri.parse(url),
      headers: headers ?? {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    final body = _decodeJsonResponse(res, requestUrl: url);
    if (body['success'] != true) {
      final msg = body['message'] ?? 'Request failed';
      if (body['errors'] != null) {
        throw Exception('$msg: ${body['errors']}');
      }
      throw Exception(msg);
    }
    return body;
  }

  /// GET [ApiConfig.rootIndexUrl] — same JSON as opening `api/index.php` in the browser.
  static Future<Map<String, dynamic>> fetchApiRoot() async {
    return _get(
      ApiConfig.rootIndexUrl,
      headers: const {'Accept': 'application/json'},
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _post(
      ApiConfig.auth('login.php'),
      {'userEmail': email, 'userPassword': password},
    );
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    String contact = '',
    required bool acceptTerms,
    required bool acceptPrivacy,
  }) async {
    return _post(
      ApiConfig.auth('register.php'),
      {
        'userName': name,
        'userEmail': email,
        'userPassword': password,
        'confirmPassword': confirmPassword,
        'userContact': contact,
        'accept_terms': acceptTerms ? 1 : 0,
        'accept_privacy': acceptPrivacy ? 1 : 0,
      },
    );
  }

  /// Same flow as the website: email → 6-digit OTP → new password.
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    return _post(
      ApiConfig.auth('forgot_password_request.php'),
      {'email': email},
    );
  }

  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return _post(
      ApiConfig.auth('forgot_password_confirm.php'),
      {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> fetchDocumentTypes() async {
    final body = await _get(
      ApiConfig.meta('types.php'),
      headers: _jsonHeaders(),
    );
    final list = (body['data']?['types'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchIssuers() async {
    final body = await _get(
      ApiConfig.meta('issuers.php'),
      headers: _jsonHeaders(),
    );
    final list = (body['data']?['issuers'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchMyDocuments() async {
    final body = await _get(
      ApiConfig.documents('list.php'),
      headers: _jsonHeaders(),
    );
    final list = (body['data']?['documents'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> fetchDocumentDetail(String id) async {
    final body = await _get(
      '${ApiConfig.documents('detail.php')}?id=${Uri.encodeComponent(id)}',
      headers: _jsonHeaders(),
    );
    final doc = body['data']?['document'];
    if (doc is! Map) {
      throw Exception('Invalid document payload');
    }
    return Map<String, dynamic>.from(doc);
  }

  /// Binary stream of document request attachment (JWT; seeker must own the row).
  static Future<Uint8List> fetchDocumentAttachmentBytes(String documentId) async {
    final uri = Uri.parse(ApiConfig.documents('attachment.php')).replace(
      queryParameters: {'id': documentId},
    );
    final res = await http.get(uri, headers: SessionStore.authHeaders());
    final raw = res.body;
    final ct = (res.headers['content-type'] ?? '').toLowerCase();
    final lead = _leadingTrimBody(raw);

    final isBinaryOk = res.statusCode == 200 &&
        !lead.startsWith('<') &&
        (ct.contains('image/') ||
            ct.contains('application/pdf') ||
            ct.contains('application/octet-stream'));
    if (isBinaryOk) {
      return res.bodyBytes;
    }

    final errMap = _tryDecodeJsonMap(raw);
    if (errMap != null) {
      throw Exception(errMap['message']?.toString() ?? 'Request failed');
    }
    if (lead.startsWith('<') ||
        lead.toLowerCase().contains('<br') ||
        lead.toLowerCase().contains('<html')) {
      throw Exception('Server returned HTML instead of the attachment.');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('Please sign in again.');
    }
    if (res.statusCode != 200) {
      throw Exception('Could not load attachment (HTTP ${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  /// Tries [attachment.php] then JSON [attachment_inline.php].
  static Future<Uint8List> fetchDocumentAttachmentBytesReliable(String documentId) async {
    try {
      return await fetchDocumentAttachmentBytes(documentId);
    } catch (_) {
      final uri = Uri.parse(ApiConfig.documents('attachment_inline.php')).replace(
        queryParameters: {'id': documentId},
      );
      final res = await http.get(uri, headers: SessionStore.authHeaders());
      final body = _decodeJsonResponse(res, requestUrl: uri.toString());
      final b64 = body['data']?['base64']?.toString();
      if (b64 == null || b64.isEmpty) {
        throw Exception('Could not load attachment.');
      }
      return base64Decode(b64);
    }
  }

  static Future<void> deleteDocument(String documentId) async {
    await _post(
      ApiConfig.documents('delete.php'),
      {'documentID': documentId},
      headers: _jsonHeaders(),
    );
  }

  static Future<String> submitDocument({
    required int issuerUserId,
    required int typeId,
    required String description,
    required String location,
    File? attachment,
    String? paymentReference,
  }) async {
    final uri = Uri.parse(ApiConfig.documents('submit.php'));
    final req = http.MultipartRequest('POST', uri);
    final headers = SessionStore.authHeaders();
    req.headers.addAll(headers);
    req.fields['issuerId'] = '$issuerUserId';
    req.fields['typeId'] = '$typeId';
    req.fields['description'] = description;
    req.fields['location'] = location;
    if (paymentReference != null && paymentReference.trim().isNotEmpty) {
      req.fields['paymentReference'] = paymentReference.trim();
    }
    if (attachment != null) {
      req.files.add(
        await http.MultipartFile.fromPath('image', attachment.path),
      );
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = _decodeJsonResponse(res, requestUrl: uri.toString());
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Submit failed');
    }
    return (body['data']?['documentID'] ?? body['data']?['documentId'])
            ?.toString() ??
        '';
  }

  /// Paystack init for the Flutter app only: `actions/initialize_payment_document_seeker.php`
  /// (HTML return page after checkout). The live web app keeps using `initialize_payment.php` unchanged.
  static Future<Map<String, dynamic>> initializeRetrievalPayment({
    required double amount,
    required String email,
    required int userId,
    String description = 'Document Retrieval Fee',
  }) async {
    final url = ApiConfig.payments('initialize_payment_document_seeker.php');
    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'amount': amount.toStringAsFixed(2),
        'email': email,
        'description': description,
        'userID': userId.toString(),
      },
    );
    return _decodeAnyJson(res, requestUrl: url);
  }

  /// Same Paystack verify endpoint used by web submit form (`actions/verify_payment.php`).
  static Future<Map<String, dynamic>> verifyRetrievalPayment(String reference) async {
    final url =
        '${ApiConfig.payments('verify_payment.php')}?reference=${Uri.encodeComponent(reference)}';
    final res = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'});
    return _decodeAnyJson(res, requestUrl: url);
  }

  static Future<Map<String, dynamic>> trackDocument(String documentId) async {
    final body = await _get(
      '${ApiConfig.documents('track.php')}?id=${Uri.encodeComponent(documentId)}',
      headers: _jsonHeaders(),
    );
    final doc = body['data']?['document'];
    if (doc is! Map) {
      throw Exception('Invalid response');
    }
    return Map<String, dynamic>.from(doc);
  }

  /// Messages + institution label (same thread as web `ChatController::fetch`).
  static Future<({List<Map<String, dynamic>> messages, String issuerName})> fetchChatThread(
    String documentId,
  ) async {
    final body = await _get(
      '${ApiConfig.chat('messages.php')}?documentID=${Uri.encodeComponent(documentId)}',
      headers: _jsonHeaders(),
    );
    final raw = body['data']?['messages'] ?? body['messages'];
    final list = (raw is List) ? raw : const [];
    final messages = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final issuerName = body['data']?['issuerName']?.toString() ?? '';
    return (messages: messages, issuerName: issuerName);
  }

  static Future<List<Map<String, dynamic>>> fetchChatMessages(String documentId) async {
    final t = await fetchChatThread(documentId);
    return t.messages;
  }

  static Future<void> sendChatMessage(String documentId, String message) async {
    await _post(
      ApiConfig.chat('send.php'),
      {'documentID': documentId, 'message': message},
      headers: _jsonHeaders(),
    );
  }

  static Future<List<Map<String, dynamic>>> fetchPrelossList() async {
    final body = await _get(
      ApiConfig.preloss('list.php'),
      headers: _jsonHeaders(),
    );
    final list = (body['data']?['items'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Binary stream of a pre-loss file (JWT). Same authorization as list/delete; mirrors web `view_image`.
  static Future<Uint8List> fetchPrelossFileBytes(
    int prelossId, {
    bool download = false,
  }) async {
    final uri = Uri.parse(ApiConfig.preloss('file.php')).replace(
      queryParameters: {
        'id': '$prelossId',
        if (download) 'download': '1',
      },
    );
    final res = await http.get(uri, headers: SessionStore.authHeaders());
    final raw = res.body;
    final ct = (res.headers['content-type'] ?? '').toLowerCase();
    final lead = _leadingTrimBody(raw);

    final isBinaryOk = res.statusCode == 200 &&
        !lead.startsWith('<') &&
        (ct.contains('image/') ||
            ct.contains('application/pdf') ||
            ct.contains('application/octet-stream'));
    if (isBinaryOk) {
      return res.bodyBytes;
    }

    final errMap = _tryDecodeJsonMap(raw);
    if (errMap != null) {
      throw Exception(errMap['message']?.toString() ?? 'Request failed');
    }
    if (lead.startsWith('<') ||
        lead.toLowerCase().contains('<br') ||
        lead.toLowerCase().contains('<html')) {
      throw Exception(
        'Server returned HTML instead of the file (often a PHP warning). '
        'Redeploy api/config/database.php and api/preloss/file.php, and check the host PHP error log.',
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('Please sign in again.');
    }
    if (res.statusCode != 200) {
      throw Exception('Could not load file (HTTP ${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  /// Tries binary [file.php], then JSON base64 [file_inline.php] (same JWT) so previews work on more hosts.
  static Future<Uint8List> fetchPrelossFileBytesReliable(
    int prelossId, {
    bool download = false,
  }) async {
    try {
      return await fetchPrelossFileBytes(prelossId, download: download);
    } catch (_) {
      final uri = Uri.parse(ApiConfig.preloss('file_inline.php')).replace(
        queryParameters: {'id': '$prelossId'},
      );
      final res = await http.get(uri, headers: SessionStore.authHeaders());
      final body = _decodeJsonResponse(res, requestUrl: uri.toString());
      final b64 = body['data']?['base64']?.toString();
      if (b64 == null || b64.isEmpty) {
        throw Exception('Could not load this backup.');
      }
      return base64Decode(b64);
    }
  }

  /// Returns new [prelossID] when the server includes it (deploy latest `upload.php`).
  static Future<int?> uploadPreloss({required String title, required File file}) async {
    final uri = Uri.parse(ApiConfig.preloss('upload.php'));
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(SessionStore.authHeaders());
    req.fields['title'] = title;
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: p.basename(file.path),
      ),
    );
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = _decodeJsonResponse(res, requestUrl: uri.toString());
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Upload failed');
    }
    final idRaw = body['data']?['prelossID'] ?? body['data']?['prelossId'];
    if (idRaw is int) return idRaw;
    return int.tryParse(idRaw?.toString() ?? '');
  }

  static Future<void> deletePreloss(int prelossId) async {
    await _post(
      ApiConfig.preloss('delete.php'),
      {'prelossID': prelossId},
      headers: _jsonHeaders(),
    );
  }
}
