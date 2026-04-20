<?php
/**
 * Default document for https://example.com/api/ — avoids Apache "403 Forbidden" when
 * directory listing is disabled and no index file exists.
 */
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
http_response_code(200);
echo json_encode([
    'success' => true,
    'message' => 'Tshijuka RDP Document Seeker API',
    'paths' => [
        'register' => 'auth/register.php',
        'login' => 'auth/login.php',
        'forgot_password_request' => 'auth/forgot_password_request.php',
        'forgot_password_confirm' => 'auth/forgot_password_confirm.php',
        'chat_messages' => 'chat/messages.php',
        'chat_send' => 'chat/send.php',
    ],
], JSON_UNESCAPED_UNICODE);
