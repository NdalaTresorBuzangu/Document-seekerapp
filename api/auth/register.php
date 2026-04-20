<?php
/**
 * Register a Document Seeker — App\Services\AuthService::register (same DB as web).
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

$name = trim((string) ($input['userName'] ?? $input['name'] ?? ''));
$email = trim((string) ($input['userEmail'] ?? $input['email'] ?? ''));
$password = (string) ($input['userPassword'] ?? $input['password'] ?? '');
$confirm = (string) ($input['confirmPassword'] ?? $input['confirm_password'] ?? $password);
$contact = trim((string) ($input['userContact'] ?? $input['contact'] ?? ''));
$acceptTerms = !empty($input['accept_terms']) || !empty($input['acceptTerms']);
$acceptPrivacy = !empty($input['accept_privacy']) || !empty($input['acceptPrivacy']);

if ($name === '' || $email === '' || $password === '') {
    ds_api_json(['success' => false, 'message' => 'Name, email, and password are required.'], 422);
}

try {
    $db = getDB();
    $auth = new AuthService($db);
    $result = $auth->register([
        'name' => $name,
        'email' => $email,
        'password' => $password,
        'confirmPassword' => $confirm,
        'role' => 'Document Seeker',
        'contact' => $contact,
        'accept_terms' => $acceptTerms,
        'accept_privacy' => $acceptPrivacy,
    ]);

    if (!$result['success']) {
        ds_api_json(['success' => false, 'message' => $result['message'] ?? 'Registration failed.'], 422);
    }

    ds_api_json([
        'success' => true,
        'message' => $result['message'] ?? 'Registration successful.',
        'data' => ['userId' => $result['userId'] ?? null],
    ]);
} catch (Throwable $e) {
    ds_api_json(['success' => false, 'message' => 'Server error.', 'error' => $e->getMessage()], 500);
}
