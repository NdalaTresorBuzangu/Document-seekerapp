<?php

/**
 * Return pre-loss file as base64 JSON (JWT) — fallback when binary GET is blocked or mis-routed.
 * Same auth and path rules as file.php; size-capped to avoid huge JSON payloads.
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';
require_once __DIR__ . DIRECTORY_SEPARATOR . 'preloss_paths.php';

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    ds_api_json(['success' => false, 'message' => 'Use GET.'], 405);
}

$auth = ds_api_require_seeker();
$userId = (int) $auth['user_id'];

$prelossId = (int) ($_GET['id'] ?? $_GET['prelossID'] ?? 0);
if ($prelossId <= 0) {
    ds_api_json(['success' => false, 'message' => 'Invalid document id.'], 422);
}

$db = getDB();
$stmt = $db->prepare('SELECT filePath FROM PrelossDocuments WHERE prelossID = ? AND userID = ?');
if (!$stmt) {
    ds_api_json(['success' => false, 'message' => 'Database error.'], 500);
}
$stmt->bind_param('ii', $prelossId, $userId);
$stmt->execute();
$res = $stmt->get_result();
$row = $res->fetch_assoc();
$stmt->close();

if (!$row) {
    ds_api_json(['success' => false, 'message' => 'Document not found or access denied.'], 404);
}

$fullPath = ds_preloss_resolve_existing_file((string) $row['filePath'], DS_PROJECT_ROOT);
if ($fullPath === null) {
    ds_api_json(['success' => false, 'message' => 'Could not open this backup from storage.'], 404);
}

$prelossDir = DS_PROJECT_ROOT . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'images' . DIRECTORY_SEPARATOR . 'preloss';
$canonicalPreloss = realpath($prelossDir);
$canonicalFile = realpath($fullPath);
if ($canonicalFile !== false && $canonicalPreloss !== false) {
    if (!str_starts_with($canonicalFile, $canonicalPreloss)) {
        ds_api_json(['success' => false, 'message' => 'Invalid file location.'], 400);
    }
} elseif ($canonicalFile === false || $canonicalPreloss === false) {
    $normDir = strtolower(str_replace('\\', '/', rtrim($prelossDir, '/\\')) . '/');
    $normFile = strtolower(str_replace('\\', '/', $fullPath));
    if (!str_starts_with($normFile, $normDir)) {
        ds_api_json(['success' => false, 'message' => 'Invalid file location.'], 400);
    }
}

$size = filesize($fullPath);
if ($size === false) {
    ds_api_json(['success' => false, 'message' => 'Could not read file.'], 500);
}

$maxBytes = 8 * 1024 * 1024;
if ($size > $maxBytes) {
    ds_api_json(['success' => false, 'message' => 'File is too large for inline preview.'], 413);
}

$ext = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));
$mimes = [
    'jpg' => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
];
$mime = $mimes[$ext] ?? 'application/octet-stream';

$raw = file_get_contents($fullPath);
if ($raw === false) {
    ds_api_json(['success' => false, 'message' => 'Could not read file.'], 500);
}

ds_api_json([
    'success' => true,
    'message' => 'OK',
    'data' => [
        'mime' => $mime,
        'fileName' => basename($fullPath),
        'base64' => base64_encode($raw),
    ],
]);
