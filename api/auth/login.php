<?php
/**
 * Document Seeker login — uses App\Services\AuthService (same rules as web).
 * Response shape aligned with WasteJustice-style mobile APIs: success, message, data.
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

use App\Services\AuthService;

ds_api_cors();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    ds_api_json(['success' => false, 'message' => 'Use POST with JSON body.'], 405);
}

$raw = file_get_contents('php://input');
$input = is_string($raw) ? (json_decode($raw, true) ?: []) : [];
$email = trim((string) ($input['userEmail'] ?? $input['email'] ?? ''));
$password = (string) ($input['userPassword'] ?? $input['password'] ?? '');

if ($email === '' || $password === '') {
    ds_api_json(['success' => false, 'message' => 'Email and password are required.'], 422);
}

try {
    $db = getDB();
    $auth = new AuthService($db);
    $result = $auth->login($email, $password);
    if (!$result['success']) {
        ds_api_json(['success' => false, 'message' => $result['message'] ?? 'Login failed.'], 401);
    }
    $user = $result['user'];
    $role = trim((string) ($user['userRole'] ?? ''));
    if ($role !== 'Document Seeker') {
        ds_api_json([
            'success' => false,
            'message' => 'This mobile app is only for Document Seeker accounts.',
        ], 403);
    }

    $userId = (int) ($user['userID'] ?? 0);
    if ($userId <= 0) {
        ds_api_json(['success' => false, 'message' => 'Invalid user record.'], 500);
    }

    unset($user['userPassword']);
    $token = ds_jwt_issue($userId, 'Document Seeker');

    ds_api_json([
        'success' => true,
        'message' => 'Login successful',
        'data' => [
            'token' => $token,
            'user' => [
                'userID' => $userId,
                'userName' => $user['userName'] ?? '',
                'userEmail' => $user['userEmail'] ?? '',
                'userRole' => $role,
                'userContact' => $user['userContact'] ?? '',
            ],
        ],
    ]);
} catch (Throwable $e) {
    ds_api_json(['success' => false, 'message' => 'Server error.', 'error' => $e->getMessage()], 500);
}
