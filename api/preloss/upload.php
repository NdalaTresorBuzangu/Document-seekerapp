<?php
/**
 * Upload one pre-loss document (title + file) — same validation/INSERT as actions/preloss_upload_action.php
 * (single row; web supports multiple rows in one POST).
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    ds_api_json(['success' => false, 'message' => 'Invalid method.'], 405);
}

$auth = ds_api_require_seeker();
$userID = (int) $auth['user_id'];

$title = trim((string) ($_POST['title'] ?? ''));
if ($title === '') {
    ds_api_json(['success' => false, 'message' => 'Title is required.'], 422);
}

$file = $_FILES['file'] ?? null;
if (!is_array($file) || ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
    ds_api_json(['success' => false, 'message' => 'A valid file upload is required.'], 422);
}

$allowed = ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp'];
$maxSize = 10 * 1024 * 1024;
$origName = (string) ($file['name'] ?? '');
$ext = strtolower(pathinfo($origName, PATHINFO_EXTENSION));
if (!in_array($ext, $allowed, true)) {
    ds_api_json(['success' => false, 'message' => 'Only PDF and image files (JPG, PNG, GIF, WebP) allowed.'], 422);
}
$size = (int) ($file['size'] ?? 0);
if ($size > $maxSize) {
    ds_api_json(['success' => false, 'message' => 'File too large (max 10 MB).'], 422);
}

$projectRoot = DS_PROJECT_ROOT;
$uploadDir = $projectRoot . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'images' . DIRECTORY_SEPARATOR . 'preloss' . DIRECTORY_SEPARATOR;
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0777, true);
}

$safeName = time() . '_0_' . preg_replace('/[^a-zA-Z0-9._-]/', '_', $origName);
$targetPath = $uploadDir . $safeName;
$tmp = (string) ($file['tmp_name'] ?? '');
if ($tmp === '' || !is_uploaded_file($tmp) || !move_uploaded_file($tmp, $targetPath)) {
    ds_api_json(['success' => false, 'message' => 'Failed to save file.'], 500);
}

$filePath = 'uploads/images/preloss/' . $safeName;
$db = getDB();
$stmt = $db->prepare('INSERT INTO PrelossDocuments (userID, title, filePath) VALUES (?, ?, ?)');
if (!$stmt) {
    @unlink($targetPath);
    ds_api_json(['success' => false, 'message' => 'Database error.'], 500);
}
$stmt->bind_param('iss', $userID, $title, $filePath);
if (!$stmt->execute()) {
    @unlink($targetPath);
    $stmt->close();
    ds_api_json(['success' => false, 'message' => 'Failed to save record.'], 500);
}
$prelossID = (int) $db->insert_id;
$stmt->close();

ds_api_json([
    'success' => true,
    'message' => 'Document saved successfully.',
    'data' => [
        'prelossID' => $prelossID,
        'filePath' => $filePath,
    ],
]);
