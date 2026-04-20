<?php
/**
 * List pre-loss stored documents for the seeker — same data as views/preloss.php query.
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

$db = getDB();
$stmt = $db->prepare('SELECT prelossID, title, filePath, uploadedOn FROM PrelossDocuments WHERE userID = ? ORDER BY uploadedOn DESC');
$stmt->bind_param('i', $userId);
$stmt->execute();
$res = $stmt->get_result();
$rows = [];
while ($row = $res->fetch_assoc()) {
    $rows[] = $row;
}
$stmt->close();

ds_api_json([
    'success' => true,
    'message' => 'OK',
    'data' => ['items' => $rows],
]);
