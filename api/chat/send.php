<?php
/**
 * Send chat message — same rules as actions/chat_action.php (web).
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    ds_api_json(['success' => false, 'message' => 'Method not allowed.'], 405);
}

$auth = ds_api_require_seeker();
$senderID = (int) $auth['user_id'];

$raw = file_get_contents('php://input');
$input = is_string($raw) ? (json_decode($raw, true) ?: []) : [];
$documentID = trim((string) ($input['documentID'] ?? $_POST['documentID'] ?? ''));
$message = trim((string) ($input['message'] ?? $_POST['message'] ?? ''));

if ($documentID === '' || $message === '') {
    ds_api_json(['success' => false, 'message' => 'Document ID and message are required.'], 422);
}
if (strlen($message) > 2000) {
    ds_api_json(['success' => false, 'message' => 'Message is too long (max 2000 characters).'], 422);
}

$db = getDB();

$stmt = $db->prepare('SELECT 1 FROM Document WHERE documentID = ? AND (userID = ? OR documentIssuerID = ?)');
$stmt->bind_param('sii', $documentID, $senderID, $senderID);
$stmt->execute();
$allowed = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$allowed) {
    ds_api_json(['success' => false, 'message' => 'Access denied.'], 403);
}

$stmt = $db->prepare('INSERT INTO Chat (documentID, senderID, message) VALUES (?, ?, ?)');
$stmt->bind_param('sis', $documentID, $senderID, $message);
$ok = $stmt->execute();
$stmt->close();

if ($ok) {
    ds_api_json(['success' => true, 'message' => 'Sent.']);
}
ds_api_json(['success' => false, 'message' => 'Failed to send.'], 500);
