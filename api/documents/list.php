<?php
/** List document requests for the logged-in seeker (DocumentController::getBySeeker). */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

use App\Controllers\DocumentController;

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    ds_api_json(['success' => false, 'message' => 'Use GET.'], 405);
}

$auth = ds_api_require_seeker();
$userId = (int) $auth['user_id'];

try {
    $controller = new DocumentController(getDB());
    $result = $controller->getBySeeker($userId);
    $documents = $result['documents'] ?? [];
    $db = getDB();
    foreach ($documents as &$doc) {
        if (!is_array($doc)) {
            continue;
        }
        $doc['issuerId'] = $doc['documentIssuerID'] ?? null;
        // Same institution label as views/tshijuka_pack.php (Subscribe.documentIssuerName).
        $issuerId = (int) ($doc['documentIssuerID'] ?? 0);
        if ($issuerId > 0) {
            $st = $db->prepare('SELECT documentIssuerName FROM Subscribe WHERE userID = ? LIMIT 1');
            if ($st) {
                $st->bind_param('i', $issuerId);
                $st->execute();
                $sub = $st->get_result()->fetch_assoc();
                $st->close();
                $doc['documentIssuerName'] = $sub['documentIssuerName'] ?? ($doc['issuerName'] ?? '');
            } else {
                $doc['documentIssuerName'] = $doc['issuerName'] ?? '';
            }
        } else {
            $doc['documentIssuerName'] = '';
        }
    }
    unset($doc);

    ds_api_json([
        'success' => true,
        'message' => 'OK',
        'data' => ['documents' => $documents],
    ]);
} catch (Throwable $e) {
    ds_api_json(['success' => false, 'message' => 'Server error.', 'error' => $e->getMessage()], 500);
}
