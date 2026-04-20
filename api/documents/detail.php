<?php
/** Single document by ID — seeker must own the row. */

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

$auth = ds_api_require_seeker();
$userId = (int) $auth['user_id'];

$id = trim((string) ($_GET['id'] ?? $_GET['documentID'] ?? ''));
if ($id === '') {
    ds_api_json(['success' => false, 'message' => 'Missing id (documentID).'], 422);
}

try {
    $controller = new DocumentController(getDB());
    $result = $controller->getById($id);
    if (empty($result['success']) || empty($result['document'])) {
        ds_api_json(['success' => false, 'message' => $result['message'] ?? 'Not found.'], 404);
    }
    $doc = $result['document'];
    if ((int) ($doc['userID'] ?? 0) !== $userId) {
        ds_api_json(['success' => false, 'message' => 'Not authorized.'], 403);
    }
    $doc['issuerId'] = $doc['documentIssuerID'] ?? null;

    ds_api_json([
        'success' => true,
        'message' => 'OK',
        'data' => ['document' => $doc],
    ]);
} catch (Throwable $e) {
    ds_api_json(['success' => false, 'message' => 'Server error.', 'error' => $e->getMessage()], 500);
}
