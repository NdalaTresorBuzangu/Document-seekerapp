<?php
/**
 * Look up document by ID (status + details) — same SELECT idea as views/progress.php (web).
 * Requires Document Seeker JWT (mobile); web version only required logged-in seeker.
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

$documentId = trim((string) ($_GET['id'] ?? $_GET['documentId'] ?? $_GET['documentID'] ?? ''));
if ($documentId === '') {
    ds_api_json(['success' => false, 'message' => 'Missing document id.'], 422);
}

$db = getDB();
$stmt = $db->prepare(
    'SELECT r.documentID, r.description, r.imagePath, r.imageMime, r.location, r.submissionDate, s.statusName, r.statusID
     FROM Document r
     JOIN Status s ON r.statusID = s.statusID
     WHERE r.documentID = ? AND r.userID = ?'
);
$stmt->bind_param('si', $documentId, $userId);
$stmt->execute();
$result = $stmt->get_result();
$document = $result->fetch_assoc();
$stmt->close();

if (!$document) {
    ds_api_json(['success' => false, 'message' => 'Document not found. Please check the Document ID.'], 404);
}

ds_api_json([
    'success' => true,
    'message' => 'OK',
    'data' => ['document' => $document],
]);
