<?php
/**
 * Stream document request attachment (JWT seeker must own the row).
 * Uses disk `imagePath` under uploads/images/, or `imageData` BLOB when path is empty.
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

if ($fullPath !== null) {
    $imagesBase = DS_PROJECT_ROOT . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'images' . DIRECTORY_SEPARATOR;
    $realBase = realpath($imagesBase);
    $realFull = realpath($fullPath);
    if ($realBase === false || $realFull === false || !str_starts_with($realFull, $realBase)) {
        $normBase = strtolower(str_replace('\\', '/', rtrim($imagesBase, '/\\')) . '/');
        $normFull = strtolower(str_replace('\\', '/', $fullPath));
        if (!str_starts_with($normFull, $normBase)) {
            ds_api_json(['success' => false, 'message' => 'Invalid file location.'], 400);
        }
    }

    $ext = strtolower(pathinfo($realFull !== false ? $realFull : $fullPath, PATHINFO_EXTENSION));
    $mimes = [
        'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'png' => 'image/png',
        'gif' => 'image/gif', 'webp' => 'image/webp', 'pdf' => 'application/pdf',
    ];
    $mime = $mimes[$ext] ?? (trim((string) ($row['imageMime'] ?? '')) ?: 'application/octet-stream');
    $sendPath = $realFull !== false ? $realFull : $fullPath;

    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . (string) filesize($sendPath));
    header('Content-Transfer-Encoding: binary');
    header('Content-Disposition: inline; filename="' . basename($sendPath) . '"');
    readfile($sendPath);
    exit;
}

$blob = $row['imageData'] ?? null;
if ($blob !== null && $blob !== '') {
    $mime = trim((string) ($row['imageMime'] ?? ''));
    if ($mime === '') {
        $mime = 'application/octet-stream';
    }
    $len = is_string($blob) ? strlen($blob) : 0;
    if ($len === 0) {
        ds_api_json(['success' => false, 'message' => 'No attachment for this request.'], 404);
    }
    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . (string) $len);
    header('Content-Transfer-Encoding: binary');
    header('Content-Disposition: inline; filename="attachment.bin"');
    echo $blob;
    exit;
}

ds_api_json(['success' => false, 'message' => 'No attachment for this request.'], 404);
