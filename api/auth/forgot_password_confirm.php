<?php
/**
 * Forgot password — verify OTP and set new password (same rules as web AuthController::resetPasswordSubmit).
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';

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
$otp = preg_replace('/\D/', '', trim((string) ($input['otp'] ?? '')));
$newPassword = (string) ($input['new_password'] ?? $input['newPassword'] ?? '');
$confirm = (string) ($input['confirm_password'] ?? $input['confirmPassword'] ?? '');

if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    ds_api_json(['success' => false, 'message' => 'Please enter a valid email address.'], 422);
}
if (strlen($otp) !== 6 || $newPassword === '' || $newPassword !== $confirm) {
    ds_api_json(['success' => false, 'message' => 'Invalid input or passwords do not match.'], 422);
}
if (strlen($newPassword) < 6) {
    ds_api_json(['success' => false, 'message' => 'Password must be at least 6 characters.'], 422);
}

$conn = getDB();
$stmt = $conn->prepare('SELECT id, email, otpHash, expiresAt FROM PasswordResetOtp WHERE email = ? ORDER BY id DESC LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$row || !hash_equals((string) $row['otpHash'], hash('sha256', $otp))) {
    ds_api_json(['success' => false, 'message' => 'Invalid or expired code. Request a new one.'], 400);
}
if (strtotime((string) $row['expiresAt']) < time()) {
    $del = $conn->prepare('DELETE FROM PasswordResetOtp WHERE email = ?');
    $del->bind_param('s', $email);
    $del->execute();
    $del->close();
    ds_api_json(['success' => false, 'message' => 'Code has expired. Request a new one.'], 400);
}

$passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
$upd = $conn->prepare('UPDATE User SET userPassword = ? WHERE userEmail = ?');
$upd->bind_param('ss', $passwordHash, $email);
$upd->execute();
$upd->close();

$del2 = $conn->prepare('DELETE FROM PasswordResetOtp WHERE email = ?');
$del2->bind_param('s', $email);
$del2->execute();
$del2->close();

ds_api_json([
    'success' => true,
    'message' => 'Your password was updated. You can sign in now.',
    'data' => ['email' => $email],
]);
