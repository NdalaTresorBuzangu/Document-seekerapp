<?php
/**
 * Subscribed document issuing institutions (same query as views/submit_document.php).
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

ds_api_require_seeker();

try {
    $db = getDB();
    $sql = "SELECT s.subscribeID, s.documentIssuerName, u.userID AS issuerUserId
            FROM Subscribe s
            JOIN User u ON s.userID = u.userID
            WHERE u.userRole = 'Document Issuer'";
    $res = $db->query($sql);
    $rows = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $rows[] = [
                'subscribeID' => (int) ($row['subscribeID'] ?? 0),
                'documentIssuerName' => $row['documentIssuerName'] ?? '',
                'issuerUserId' => (int) ($row['issuerUserId'] ?? 0),
            ];
        }
    }
    ds_api_json([
        'success' => true,
        'message' => 'OK',
        'data' => ['issuers' => $rows],
    ]);
} catch (Throwable $e) {
    ds_api_json(['success' => false, 'message' => 'Server error.', 'error' => $e->getMessage()], 500);
}
