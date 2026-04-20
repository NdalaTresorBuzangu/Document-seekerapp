<?php
/**
 * 6-digit OTP for Document Seeker API only (same algorithm as main site `config/mfa_helper.php`).
 * Keeps forgot-password and similar flows self-contained under `api/` without loading main `mfa_helper.php`.
 */

declare(strict_types=1);

if (!function_exists('ds_otp_generate')) {
    function ds_otp_generate(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }
}
