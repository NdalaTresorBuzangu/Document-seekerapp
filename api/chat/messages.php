<?php
/**
 * List chat messages for a document — same queries as ChatController::fetch (web).
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    ds_api_json(['success' => false, 'message' => 'Use GET.'], 405);
}

$auth = ds_api_require_seeker();
$userId = (int) $auth['user_id'];

$documentID = trim((string) ($_GET['documentID'] ?? $_GET['id'] ?? ''));
if ($documentID === '') {
    ds_api_json(['success' => false, 'message' => 'Missing documentID.'], 422);
}

$db = getDB();

$stmt = $db->prepare('SELECT 1 FROM Document WHERE documentID = ? AND (userID = ? OR documentIssuerID = ?)');
$stmt->bind_param('sii', $documentID, $userId, $userId);
$stmt->execute();
$allowed = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$allowed) {
    ds_api_json(['success' => false, 'message' => 'Access denied.'], 403);
}

$issuerName = '';
$issuerUid = 0;
$stDoc = $db->prepare('SELECT documentIssuerID FROM Document WHERE documentID = ? LIMIT 1');
if ($stDoc) {
    $stDoc->bind_param('s', $documentID);
    $stDoc->execute();
    $rowDoc = $stDoc->get_result()->fetch_assoc();
    $stDoc->close();
    if (is_array($rowDoc)) {
        $issuerUid = (int) ($rowDoc['documentIssuerID'] ?? 0);
    }
}
if ($issuerUid > 0) {
    $stSub = $db->prepare(
        "SELECT documentIssuerName FROM Subscribe WHERE userID = ? AND roleType = 'Document Issuer' LIMIT 1"
    );
    if ($stSub) {
        $stSub->bind_param('i', $issuerUid);
        $stSub->execute();
        $sub = $stSub->get_result()->fetch_assoc();
        $stSub->close();
        $issuerName = is_array($sub) ? trim((string) ($sub['documentIssuerName'] ?? '')) : '';
    }
    if ($issuerName === '') {
        $stU = $db->prepare('SELECT userName FROM User WHERE userID = ? LIMIT 1');
        if ($stU) {
            $stU->bind_param('i', $issuerUid);
            $stU->execute();
            $uRow = $stU->get_result()->fetch_assoc();
            $stU->close();
            $issuerName = is_array($uRow) ? trim((string) ($uRow['userName'] ?? '')) : '';
        }
    }
}

$stmt = $db->prepare(
    'SELECT c.chatID, c.message, c.timestamp, c.senderID, u.userName
     FROM Chat c
     JOIN User u ON c.senderID = u.userID
     WHERE c.documentID = ?
     ORDER BY c.timestamp ASC'
);
$stmt->bind_param('s', $documentID);
$stmt->execute();
$result = $stmt->get_result();
$messages = [];
while ($row = $result->fetch_assoc()) {
    $messages[] = [
        'chatID' => (int) $row['chatID'],
        'senderID' => (int) $row['senderID'],
        'userName' => $row['userName'],
        'message' => $row['message'],
        'timestamp' => $row['timestamp'],
        'isMe' => (int) $row['senderID'] === $userId,
    ];
}
$stmt->close();

ds_api_json([
    'success' => true,
    'message' => 'OK',
    'data' => [
        'messages' => $messages,
        'issuerName' => $issuerName,
        'documentID' => $documentID,
    ],
    // Older app builds read top-level `messages` only.
    'messages' => $messages,
]);
