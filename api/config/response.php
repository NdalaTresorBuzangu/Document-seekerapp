<?php
/**
 * API response helpers + CORS + JWT — same layout as WasteJustice `fluutter app/api/config/response.php`
 * (single file for JSON helpers and Bearer auth after `database.php` is loaded).
 */

declare(strict_types=1);

if (!function_exists('getallheaders')) {
    function getallheaders(): array
    {
        $headers = [];
        foreach ($_SERVER as $name => $value) {
            if (strncmp($name, 'HTTP_', 5) === 0) {
                $key = str_replace(' ', '-', ucwords(strtolower(str_replace('_', ' ', substr($name, 5)))));
                $headers[$key] = $value;
            }
        }
        if (isset($_SERVER['CONTENT_TYPE'])) {
            $headers['Content-Type'] = $_SERVER['CONTENT_TYPE'];
        }
        return $headers;
    }
}

if (!function_exists('sendSuccessResponse')) {
    function sendSuccessResponse($data = null, string $message = 'Success', int $statusCode = 200): void
    {
        http_response_code($statusCode);
        header('Content-Type: application/json; charset=utf-8');

        $response = [
            'success' => true,
            'message' => $message,
            'data' => $data,
            'timestamp' => date('Y-m-d H:i:s'),
        ];

        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        exit;
    }
}

if (!function_exists('sendErrorResponse')) {
    function sendErrorResponse(string $message = 'Error occurred', int $statusCode = 400, $data = null): void
    {
        http_response_code($statusCode);
        header('Content-Type: application/json; charset=utf-8');

        $response = [
            'success' => false,
            'message' => $message,
            'data' => $data,
            'timestamp' => date('Y-m-d H:i:s'),
        ];

        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        exit;
    }
}

if (!function_exists('sendValidationErrorResponse')) {
    function sendValidationErrorResponse(array $errors): void
    {
        http_response_code(422);
        header('Content-Type: application/json; charset=utf-8');

        $response = [
            'success' => false,
            'message' => 'Validation failed',
            'errors' => $errors,
            'timestamp' => date('Y-m-d H:i:s'),
        ];

        echo json_encode($response, JSON_UNESCAPED_UNICODE);
        exit;
    }
}

if (!function_exists('sendUnauthorizedResponse')) {
    function sendUnauthorizedResponse(string $message = 'Unauthorized access'): void
    {
        sendErrorResponse($message, 401);
    }
}

if (!function_exists('sendNotFoundResponse')) {
    function sendNotFoundResponse(string $message = 'Resource not found'): void
    {
        sendErrorResponse($message, 404);
    }
}

if (!function_exists('sendServerErrorResponse')) {
    function sendServerErrorResponse(string $message = 'Internal server error'): void
    {
        sendErrorResponse($message, 500);
    }
}

if (!function_exists('validateRequiredFields')) {
    function validateRequiredFields(array $data, array $requiredFields): array
    {
        $errors = [];

        foreach ($requiredFields as $field) {
            if (!array_key_exists($field, $data)) {
                $errors[$field] = ucfirst(str_replace('_', ' ', $field)) . ' is required';
                continue;
            }
            $value = $data[$field];
            if ($value === null || $value === '') {
                $errors[$field] = ucfirst(str_replace('_', ' ', $field)) . ' is required';
                continue;
            }
            if (is_string($value) && trim($value) === '') {
                $errors[$field] = ucfirst(str_replace('_', ' ', $field)) . ' is required';
            }
        }

        return $errors;
    }
}

if (!function_exists('sanitizeInput')) {
    function sanitizeInput($data)
    {
        if (is_array($data)) {
            return array_map('sanitizeInput', $data);
        }
        if (is_int($data) || is_float($data) || is_bool($data)) {
            return $data;
        }
        if ($data === null) {
            return null;
        }
        $str = (string) $data;
        return htmlspecialchars(strip_tags(trim($str)), ENT_QUOTES, 'UTF-8');
    }
}

if (!function_exists('getJsonInput')) {
    function getJsonInput(): array
    {
        $json = file_get_contents('php://input');
        $decoded = json_decode($json, true);

        return is_array($decoded) ? $decoded : [];
    }
}

/**
 * CORS headers for mobile / browser clients.
 */
if (!function_exists('ds_api_cors')) {
    function ds_api_cors(): void
    {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization');
    }
}

/**
 * Low-level JSON exit (used where the envelope is not `sendSuccessResponse` shape).
 */
if (!function_exists('ds_api_json')) {
    function ds_api_json(array $data, int $statusCode = 200): void
    {
        http_response_code($statusCode);
        header('Content-Type: application/json; charset=utf-8');
        $flags = JSON_UNESCAPED_UNICODE;
        if (defined('JSON_INVALID_UTF8_SUBSTITUTE')) {
            $flags |= JSON_INVALID_UTF8_SUBSTITUTE;
        }
        echo json_encode($data, $flags);
        exit;
    }
}

// --- HS256 JWT (same behaviour as former `jwt.php`; WasteJustice keeps token helpers in `response.php`) ---

if (!function_exists('ds_jwt_secret')) {
    function ds_jwt_secret(): string
    {
        $env = getenv('DOCUMENT_SEEKER_JWT_SECRET');
        if (is_string($env) && $env !== '') {
            return $env;
        }

        return 'tshijuka-document-seeker-dev-secret-change-me';
    }
}

if (!function_exists('ds_jwt_b64url_encode')) {
    function ds_jwt_b64url_encode(string $raw): string
    {
        return rtrim(strtr(base64_encode($raw), '+/', '-_'), '=');
    }
}

if (!function_exists('ds_jwt_b64url_decode')) {
    function ds_jwt_b64url_decode(string $b64): string
    {
        $pad = strlen($b64) % 4;
        if ($pad > 0) {
            $b64 .= str_repeat('=', 4 - $pad);
        }

        return base64_decode(strtr($b64, '-_', '+/'), true) ?: '';
    }
}

/**
 * @return array{user_id:int,user_role:string,exp:int}|null
 */
if (!function_exists('ds_jwt_decode_verify')) {
    function ds_jwt_decode_verify(string $jwt): ?array
    {
        $parts = explode('.', $jwt);
        if (count($parts) !== 3) {
            return null;
        }
        [$h, $p, $s] = $parts;
        $signing = $h . '.' . $p;
        $expected = ds_jwt_b64url_encode(hash_hmac('sha256', $signing, ds_jwt_secret(), true));
        if (!hash_equals($expected, $s)) {
            return null;
        }
        $payloadJson = ds_jwt_b64url_decode($p);
        $payload = json_decode($payloadJson, true);
        if (!is_array($payload)) {
            return null;
        }
        $uid = $payload['user_id'] ?? null;
        $role = $payload['user_role'] ?? '';
        $exp = $payload['exp'] ?? 0;
        if (!is_int($uid) && !is_numeric($uid)) {
            return null;
        }
        if (!is_string($role) || $role === '') {
            return null;
        }
        if (!is_int($exp) || $exp < time()) {
            return null;
        }

        return [
            'user_id' => (int) $uid,
            'user_role' => $role,
            'exp' => $exp,
        ];
    }
}

if (!function_exists('ds_jwt_issue')) {
    function ds_jwt_issue(int $userId, string $userRole, int $ttlSeconds = 604800): string
    {
        $payload = [
            'user_id' => $userId,
            'user_role' => $userRole,
            'iat' => time(),
            'exp' => time() + $ttlSeconds,
        ];
        $header = ['typ' => 'JWT', 'alg' => 'HS256'];
        $h = ds_jwt_b64url_encode(json_encode($header, JSON_UNESCAPED_UNICODE));
        $p = ds_jwt_b64url_encode(json_encode($payload, JSON_UNESCAPED_UNICODE));
        $signing = $h . '.' . $p;
        $sig = ds_jwt_b64url_encode(hash_hmac('sha256', $signing, ds_jwt_secret(), true));

        return $signing . '.' . $sig;
    }
}

/**
 * @return array{user_id:int,user_role:string}|null
 */
if (!function_exists('ds_api_current_user')) {
    function ds_api_current_user(): ?array
    {
        $headers = function_exists('getallheaders') ? getallheaders() : [];
        if (!is_array($headers)) {
            $headers = [];
        }
        $auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        if ($auth === '' && !empty($_SERVER['HTTP_AUTHORIZATION'])) {
            $auth = (string) $_SERVER['HTTP_AUTHORIZATION'];
        }
        if ($auth === '' && !empty($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
            $auth = (string) $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        }
        if ($auth === '' || !preg_match('/Bearer\s+(\S+)/i', $auth, $m)) {
            return null;
        }
        $decoded = ds_jwt_decode_verify($m[1]);
        if ($decoded === null) {
            return null;
        }

        return ['user_id' => $decoded['user_id'], 'user_role' => $decoded['user_role']];
    }
}

/**
 * @return array{user_id: int, user_role: string}
 */
if (!function_exists('ds_api_require_seeker')) {
    function ds_api_require_seeker(): array
    {
        $u = ds_api_current_user();
        if ($u === null) {
            ds_api_json(['success' => false, 'message' => 'Authentication required.'], 401);
        }
        if (($u['user_role'] ?? '') !== 'Document Seeker') {
            ds_api_json(['success' => false, 'message' => 'This app is for Document Seekers only.'], 403);
        }

        return $u;
    }
}
