<?php
/**
 * Stream a pre-loss file for the logged-in seeker (JWT) — same disk layout as
 * `DocumentController::view_image` / `views/view_image.php`, without web session.
 *
 * GET ?id=<prelossID>  [&download=1]
 * Header: Authorization: Bearer <jwt>
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

$download = isset($_GET['download']) && (string) $_GET['download'] === '1';

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

$projectRoot = DS_PROJECT_ROOT;
$prelossDir = $projectRoot . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'images' . DIRECTORY_SEPARATOR . 'preloss';

$fullPath = ds_preloss_resolve_existing_file((string) $row['filePath'], $projectRoot);
if ($fullPath === null) {
    ds_api_json(['success' => false, 'message' => 'Could not open this backup from storage.'], 404);
}

$canonicalPreloss = realpath($prelossDir);
$canonicalFile = realpath($fullPath);
if ($canonicalFile !== false && $canonicalPreloss !== false) {
    if (!str_starts_with($canonicalFile, $canonicalPreloss)) {
        ds_api_json(['success' => false, 'message' => 'Invalid file location.'], 400);
    }
    $realFull = $canonicalFile;
} else {
    $normDir = strtolower(str_replace('\\', '/', rtrim($prelossDir, '/\\')) . '/');
    $normFile = strtolower(str_replace('\\', '/', $fullPath));
    if (!str_starts_with($normFile, $normDir)) {
        ds_api_json(['success' => false, 'message' => 'Invalid file location.'], 400);
    }
    $realFull = $fullPath;
}

$ext = strtolower(pathinfo($realFull, PATHINFO_EXTENSION));
$mimes = [
    'jpg' => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
];
$mime = $mimes[$ext] ?? 'application/octet-stream';

while (ob_get_level() > 0) {
    ob_end_clean();
}

header('Content-Type: ' . $mime);
header('Content-Length: ' . (string) filesize($realFull));
header('Content-Transfer-Encoding: binary');
$disposition = $download ? 'attachment' : 'inline';
header('Content-Disposition: ' . $disposition . '; filename="' . basename($realFull) . '"');
readfile($realFull);
exit;
