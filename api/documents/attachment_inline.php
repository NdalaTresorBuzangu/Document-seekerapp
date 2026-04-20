<?php
/**
 * Document attachment as JSON base64 (JWT, seeker owns row) — fallback for mobile clients.
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';
require_once __DIR__ . DIRECTORY_SEPARATOR . 'attachment_resolve.php';

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    ds_api_json(['success' => false, 'message' => 'Use GET.'], 405);
}

$auth = ds_api_require_seeker();
$userId = (int) $auth['user_id'];

$documentId = trim((string) ($_GET['id'] ?? $_GET['documentID'] ?? ''));
if ($documentId === '') {
    ds_api_json(['success' => false, 'message' => 'Missing document id.'], 422);
}

$db = getDB();
$stmt = $db->prepare(
    'SELECT userID, imagePath, imageMime, imageData FROM Document WHERE documentID = ? LIMIT 1'
);
if (!$stmt) {
    ds_api_json(['success' => false, 'message' => 'Database error.'], 500);
}
$stmt->bind_param('s', $documentId);
$stmt->execute();
$res = $stmt->get_result();
$row = $res->fetch_assoc();
$stmt->close();

if (!$row) {
    ds_api_json(['success' => false, 'message' => 'Document not found.'], 404);
}
if ((int) ($row['userID'] ?? 0) !== $userId) {
    ds_api_json(['success' => false, 'message' => 'Not authorized.'], 403);
}

$path = trim((string) ($row['imagePath'] ?? ''));
$fullPath = $path !== '' ? ds_document_resolve_uploaded_file($path, DS_PROJECT_ROOT) : null;

$raw = null;
$mime = trim((string) ($row['imageMime'] ?? '')) ?: 'application/octet-stream';
$fileName = 'attachment';

if ($fullPath !== null && is_readable($fullPath)) {
    $size = filesize($fullPath);
    if ($size === false || $size > 8 * 1024 * 1024) {
        ds_api_json(['success' => false, 'message' => 'Attachment too large for inline transfer.'], 413);
    }
    $raw = file_get_contents($fullPath);
    $fileName = basename($fullPath);
    $ext = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));
    $mimes = [
        'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'png' => 'image/png',
        'gif' => 'image/gif', 'webp' => 'image/webp', 'pdf' => 'application/pdf',
    ];
    if (isset($mimes[$ext])) {
        $mime = $mimes[$ext];
    }
} else {
    $blob = $row['imageData'] ?? null;
    if ($blob === null || $blob === '') {
        ds_api_json(['success' => false, 'message' => 'No attachment for this request.'], 404);
    }
    $len = is_string($blob) ? strlen($blob) : 0;
    if ($len > 8 * 1024 * 1024) {
        ds_api_json(['success' => false, 'message' => 'Attachment too large for inline transfer.'], 413);
    }
    $raw = $blob;
}

if ($raw === false || $raw === null || $raw === '') {
    ds_api_json(['success' => false, 'message' => 'Could not read attachment.'], 500);
}

ds_api_json([
    'success' => true,
    'message' => 'OK',
    'data' => [
        'mime' => $mime,
        'fileName' => $fileName,
        'base64' => base64_encode($raw),
    ],
]);
