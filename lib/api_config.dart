/// Same pattern as WasteJustice [`fluutter app/lib/api_config.dart`]: one [baseUrl] ending in `/api`, then path helpers.
///
/// **Production:** the deployed PHP API is at `/api` on the host (same site as [webSiteBase], no extra path segment).
///
/// **Override:** `flutter run --dart-define=API_BASE_URL=http://10.0.2.2/your-path/api`
class ApiConfig {
  /// Override at build/run time when the API is not at the default path.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tshijukardp.com/api',
  );

  static const String webSiteBase = 'https://tshijukardp.com';

  /// Health / discovery document (`api/index.php`). Browsers may open `/api/`; the app must call this explicit URL.
  static String get rootIndexUrl {
    var b = baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return '$b/index.php';
  }

  static String webDocumentViewUrl(String documentId) =>
      '$webSiteBase/index.php?controller=Document&action=view_page&documentID=${Uri.encodeComponent(documentId)}';

  static String auth(String endpoint) => '$baseUrl/auth/$endpoint';
  static String meta(String endpoint) => '$baseUrl/meta/$endpoint';
  static String documents(String endpoint) => '$baseUrl/documents/$endpoint';
  static String chat(String endpoint) => '$baseUrl/chat/$endpoint';
  static String preloss(String endpoint) => '$baseUrl/preloss/$endpoint';

  /// Web actions (Paystack initialize/verify) reused by mobile submit flow.
  static String action(String endpoint) => '$webSiteBase/actions/$endpoint';
  static String payments(String endpoint) => action(endpoint);
}
