<?php
/**
 * Forgot password — request 6-digit OTP (same flow as web AuthController::passwordRecoverySubmit).
 */

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'database.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'response.php';
require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'otp_helper.php';

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
if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    ds_api_json(['success' => false, 'message' => 'Please enter a valid email address.'], 422);
}

$conn = getDB();
$stmt = $conn->prepare('SELECT userID, userName, userEmail FROM User WHERE userEmail = ?');
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    ds_api_json(['success' => false, 'message' => 'No account found for this email.'], 404);
}

$del = $conn->prepare('DELETE FROM PasswordResetOtp WHERE email = ?');
$del->bind_param('s', $email);
$del->execute();
$del->close();

$otp = ds_otp_generate();
$otpHash = hash('sha256', $otp);
$expiresAt = date('Y-m-d H:i:s', time() + 900);
$ins = $conn->prepare('INSERT INTO PasswordResetOtp (email, otpHash, expiresAt) VALUES (?, ?, ?)');
$ins->bind_param('sss', $email, $otpHash, $expiresAt);
if (!$ins->execute()) {
    $ins->close();
    ds_api_json(['success' => false, 'message' => 'Unable to create reset code. Try again.'], 500);
}
$ins->close();

$subject = 'Password reset code - Tshijuka RDP';
$body = 'Hello ' . (($user['userName'] ?? '') !== '' ? $user['userName'] : 'there') . ",\n\n"
    . 'Your password reset code is: ' . $otp . "\n\n"
    . "This code expires in 15 minutes. Do not share it.\n\n"
    . "If you did not request this, ignore this email.\n\n"
    . '— Tshijuka RDP';
$headers = "From: Tshijuka RDP <noreply@tshijuka.org>\r\nContent-Type: text/plain; charset=UTF-8\r\n";
@mail($user['userEmail'], $subject, $body, $headers);

$out = [
    'success' => true,
    'message' => 'A 6-digit code was sent to your email. It expires in 15 minutes.',
    'data' => ['email' => $email],
];
if (defined('OTP_DEBUG_SHOW_CODE') && OTP_DEBUG_SHOW_CODE) {
    $out['data']['dev_code'] = $otp;
}
ds_api_json($out);
