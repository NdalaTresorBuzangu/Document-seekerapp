<?php
/**
 * Tshijuka RDP Document Seeker API — database configuration (same role as WasteJustice `api/config/database.php`).
 *
 * DB and upload helpers come only from the main app `config/config.php` (lines 1–36 in repo): errors, `$conn`, `upload_url()`.
 * Then `config/bootstrap.php` adds autoload, `getDB()`, sessions (re-`require_once` config is a no-op).
 */

declare(strict_types=1);

/*
 * Warnings/notices must never be printed as HTML before JSON or binary responses — that breaks the
 * Flutter app (FormatException on json.decode). Log only; do not display.
 */
@ini_set('display_errors', '0');
@ini_set('html_errors', '0');

/**
 * Emit JSON on PHP fatals (failed require, redeclared function, parse errors) so clients never see an empty HTTP 500 body.
 */
if (!defined('DS_API_FATAL_SHUTDOWN_REGISTERED')) {
    define('DS_API_FATAL_SHUTDOWN_REGISTERED', true);
    register_shutdown_function(static function (): void {
        $err = error_get_last();
        if ($err === null) {
            return;
        }
        $fatalTypes = [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR];
        if (!in_array($err['type'], $fatalTypes, true)) {
            return;
        }
        if (headers_sent()) {
            return;
        }
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        $flags = JSON_UNESCAPED_UNICODE;
        if (defined('JSON_INVALID_UTF8_SUBSTITUTE')) {
            $flags |= JSON_INVALID_UTF8_SUBSTITUTE;
        }
        echo json_encode([
            'success' => false,
            'message' => 'Server error (PHP fatal).',
            'error' => $err['message'],
            'file' => $err['file'],
            'line' => $err['line'],
        ], $flags);
    });
}

// Same idea as WasteJustice `api/config/database.php`: API root directory.
if (!defined('BASE_DIR')) {
    define('BASE_DIR', dirname(__DIR__));
}

if (!defined('DS_API_BASE_DIR')) {
    define('DS_API_BASE_DIR', BASE_DIR);
}

if (!defined('APP_NAME')) {
    define('APP_NAME', 'Tshijuka RDP Document Seeker');
}

/**
 * Resolve main app root (folder that contains `config/config.php` @ lines 1–36 and `config/bootstrap.php`).
 *
 * Works when only `api/` is deployed next to the main site (`public_html/api/…` → `public_html/config/config.php`),
 * and when the API still lives under `…/Doumentseekerflutterapp/api/…` in the full repo.
 */
$__dsApiDir = dirname(__DIR__); // …/api
$__dsProjectRoot = null;
$__dsWalk = dirname($__dsApiDir);
for ($__dsI = 0; $__dsI < 12; $__dsI++) {
    $configMarker = $__dsWalk . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'config.php';
    if (is_file($configMarker)) {
        $__dsProjectRoot = $__dsWalk;
        break;
    }
    $__next = dirname($__dsWalk);
    if ($__next === $__dsWalk) {
        break;
    }
    $__dsWalk = $__next;
}
if ($__dsProjectRoot === null) {
    http_response_code(503);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'API misconfigured: place this `api` folder next to the main site so `config/config.php` (lines 1–36) exists above it, or adjust paths.',
    ], JSON_UNESCAPED_SLASHES);
    exit;
}

/** Main site root (folder containing `uploads/`, `actions/`, `config/`). Used by preloss upload/delete paths. */
if (!defined('DS_PROJECT_ROOT')) {
    define('DS_PROJECT_ROOT', $__dsProjectRoot);
}

$__dsConfigPhp = $__dsProjectRoot . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'config.php';
$__dsBootstrapPhp = $__dsProjectRoot . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'bootstrap.php';
if (!is_file($__dsConfigPhp)) {
    http_response_code(503);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'API misconfigured: missing config/config.php (main app lines 1–36) at project root.',
    ], JSON_UNESCAPED_SLASHES);
    exit;
}
if (!is_file($__dsBootstrapPhp)) {
    http_response_code(503);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'API misconfigured: missing config/bootstrap.php next to config.php.',
    ], JSON_UNESCAPED_SLASHES);
    exit;
}
require_once $__dsConfigPhp;
require_once $__dsBootstrapPhp;

/**
 * mysqli access for API scripts (mirrors WasteJustice `Database::getConnection()` style).
 */
class Database
{
    /**
     * @return \mysqli Active `$conn` from `config/config.php` (lines 7–19), via `getDB()` from bootstrap.
     */
    public function getConnection(): \mysqli
    {
        return getDB();
    }

    /**
     * Quick health check for diagnostics (optional).
     *
     * @return array{status: string, message: string}
     */
    public function testConnection(): array
    {
        try {
            $db = getDB();
            if ($db->connect_error) {
                return ['status' => 'error', 'message' => $db->connect_error];
            }
            return ['status' => 'success', 'message' => 'Database connected successfully'];
        } catch (Throwable $e) {
            return ['status' => 'error', 'message' => $e->getMessage()];
        }
    }
}
