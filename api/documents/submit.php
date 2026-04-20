<?php
/**
 * Submit a new document request — multipart (fields + optional image) or JSON without file.
 * Seeker identity comes from JWT (ignores client userId).
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

use App\Controllers\DocumentController;

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    ds_api_json(['success' => false, 'message' => 'Use POST.'], 405);
}

$auth = ds_api_require_seeker();
$userId = (int) $auth['user_id'];

$issuerId = 0;
$typeId = 0;
$description = '';
$location = '';
$paymentReference = '';

$contentType = $_SERVER['CONTENT_TYPE'] ?? '';
$isJson = stripos($contentType, 'application/json') !== false;

if ($isJson) {
    $raw = file_get_contents('php://input');
    $input = is_string($raw) ? (json_decode($raw, true) ?: []) : [];
    $issuerId = (int) ($input['issuerId'] ?? $input['documentIssuerID'] ?? 0);
    $typeId = (int) ($input['typeId'] ?? $input['documentTypeID'] ?? 0);
    $description = trim((string) ($input['description'] ?? ''));
    $location = trim((string) ($input['location'] ?? ''));
    $paymentReference = trim((string) ($input['paymentReference'] ?? ''));
    $file = null;
} else {
    $issuerId = (int) ($_POST['issuerId'] ?? $_POST['documentIssuerID'] ?? 0);
    $typeId = (int) ($_POST['typeId'] ?? $_POST['documentTypeID'] ?? 0);
    $description = trim((string) ($_POST['description'] ?? ''));
    $location = trim((string) ($_POST['location'] ?? ''));
    $paymentReference = trim((string) ($_POST['paymentReference'] ?? ''));
    $file = $_FILES['image'] ?? $_FILES['document'] ?? null;
}

if ($issuerId <= 0 || $typeId <= 0 || $description === '' || $location === '') {
    ds_api_json([
        'success' => false,
        'message' => 'Missing or invalid: issuerId, typeId, description, location.',
    ], 422);
}

try {
    $controller = new DocumentController(getDB());
    $result = $controller->submit([
        'userId' => $userId,
        'issuerId' => $issuerId,
        'typeId' => $typeId,
        'description' => $description,
        'location' => $location,
    ], is_array($file) ? $file : null);

    if (empty($result['success'])) {
        ds_api_json([
            'success' => false,
            'message' => $result['message'] ?? 'Submit failed.',
        ], 400);
    }

    $docId = $result['documentId'] ?? $result['documentID'] ?? null;
    if ($paymentReference !== '' && is_string($docId) && $docId !== '') {
        $up = getDB()->prepare('UPDATE PaystackPayments SET document_id = ? WHERE reference = ?');
        if ($up) {
            $up->bind_param('ss', $docId, $paymentReference);
            $up->execute();
            $up->close();
        }
    }
    ds_api_json([
        'success' => true,
        'message' => $result['message'] ?? 'Submitted.',
        'data' => [
            'documentId' => $docId,
            'documentID' => $docId,
        ],
    ]);
} catch (Throwable $e) {
    ds_api_json(['success' => false, 'message' => 'Server error.', 'error' => $e->getMessage()], 500);
}
