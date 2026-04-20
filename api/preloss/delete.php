<?php
/**
 * Delete a pre-loss row — same as actions/preloss_delete_action.php (web).
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';
require_once __DIR__ . DIRECTORY_SEPARATOR . 'preloss_paths.php';

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    ds_api_json(['success' => false, 'message' => 'Invalid method.'], 405);
}

$auth = ds_api_require_seeker();
$userID = (int) $auth['user_id'];

$raw = file_get_contents('php://input');
$input = is_string($raw) ? (json_decode($raw, true) ?: []) : [];
$prelossID = (int) ($input['prelossID'] ?? $_POST['prelossID'] ?? 0);
if ($prelossID <= 0) {
    ds_api_json(['success' => false, 'message' => 'Invalid document.'], 422);
}

$projectRoot = DS_PROJECT_ROOT;
$db = getDB();

$stmt = $db->prepare('SELECT filePath FROM PrelossDocuments WHERE prelossID = ? AND userID = ?');
if (!$stmt) {
    ds_api_json(['success' => false, 'message' => 'Database error.'], 500);
}
$stmt->bind_param('ii', $prelossID, $userID);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();
$stmt->close();

if (!$row) {
    ds_api_json(['success' => false, 'message' => 'Document not found or access denied.'], 404);
}

$fullPath = ds_preloss_resolve_existing_file((string) $row['filePath'], $projectRoot);
if ($fullPath !== null) {
    @unlink($fullPath);
}

$stmt = $db->prepare('DELETE FROM PrelossDocuments WHERE prelossID = ? AND userID = ?');
$stmt->bind_param('ii', $prelossID, $userID);
$stmt->execute();
$stmt->close();

ds_api_json(['success' => true, 'message' => 'Document removed.']);
