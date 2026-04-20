<?php
/** Document types from DocumentType table (same as web submit form). */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

use App\Controllers\DocumentController;

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    ds_api_json(['success' => false, 'message' => 'Use GET.'], 405);
}

ds_api_require_seeker();

try {
    $controller = new DocumentController(getDB());
    $out = $controller->getTypes();
    ds_api_json([
        'success' => true,
        'message' => 'OK',
        'data' => ['types' => $out['types'] ?? []],
    ]);
} catch (Throwable $e) {
    ds_api_json(['success' => false, 'message' => 'Server error.', 'error' => $e->getMessage()], 500);
}
