// Mirrors `config/config.php` at the project root (same Hostinger DB settings as the web app).
//
// IMPORTANT: The mobile app does **not** open a MySQL connection. PHP on the server uses
// these values via `config.php`. Flutter only talks to HTTPS endpoints in [ApiConfig].
// Keeping this file in sync helps developers see one place in Dart that matches PHP config.
//
// Security: shipping DB passwords in a client app is risky (reverse engineering). Prefer
// server-side-only secrets; this mirror exists because you asked for parity with config.php.

/// Same fields as the top of [config/config.php] (lines 3–11 and upload comment).
abstract final class ServerConfig {
  // --- PHP `ini_set` / `error_reporting` (lines 3–5) — informational only in Dart ---
  static const bool phpDisplayErrors = true;
  static const bool phpDisplayStartupErrors = true;
  /// PHP `E_ALL` — documented for parity; not used by Flutter runtime.
  static const String phpErrorReporting = 'E_ALL';

  // --- Database connection settings (Hostinger) — lines 8–11 in config.php ---
  static const String dbServerName = 'localhost';
  static const String dbUsername = 'u628771162_nd';
  static const String dbPassword = 'Ndala1950@@';
  static const String dbName = 'u628771162_ndalab';

  // --- `upload_url` comment in config.php: uploads live under this path on the server ---
  static const String uploadsImagesPrefix = 'uploads/images/';
}
