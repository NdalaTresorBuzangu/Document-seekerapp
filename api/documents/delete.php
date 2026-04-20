<?php
/** Delete a document request — seeker owns row (same DocumentController::delete rules). */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

use App\Controllers\DocumentController;

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    ds_api_json(['success' => false, 'message' => 'Use POST with JSON: documentID'], 405);
}

$auth = ds_api_require_seeker();
$userId = (int) $auth['user_id'];
$role = 'Document Seeker';

$raw = file_get_contents('php://input');
$input = is_string($raw) ? (json_decode($raw, true) ?: []) : [];
$documentId = trim((string) ($input['documentID'] ?? $input['cid'] ?? $input['id'] ?? ''));
if ($documentId === '') {
    ds_api_json(['success' => false, 'message' => 'Missing documentID.'], 422);
}

try {
    $controller = new DocumentController(getDB());
    $result = $controller->delete($documentId, $userId, $role);
    $code = !empty($result['success']) ? 200 : 400;
    ds_api_json([
        'success' => (bool) ($result['success'] ?? false),
        'message' => $result['message'] ?? '',
    ], $code);
} catch (Throwable $e) {
    ds_api_json(['success' => false, 'message' => 'Server error.', 'error' => $e->getMessage()], 500);
}
