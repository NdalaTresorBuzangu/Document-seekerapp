<?php

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'site_roots.php';

/**
 * Resolve `PrelossDocuments.filePath` to an existing readable absolute path.
 *
 * Canonical DB value: `uploads/images/preloss/<safeName>` (web + API upload).
 * Web viewer uses `path=preloss/<basename>` under `uploads/images/` only.
 */
function ds_preloss_resolve_existing_file(string $storedFilePath, string $projectRoot): ?string
{
    $stored = ltrim(str_replace('\\', '/', trim($storedFilePath)), '/');
    if ($stored === '' || str_contains($stored, '..')) {
        return null;
    }

    $lower = strtolower($stored);
    $base = basename($stored);
    if ($base === '' || $base === '.' || $base === '..') {
        return null;
    }

    foreach (ds_api_site_roots($projectRoot) as $root) {
        $imagesRoot = $root . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'images' . DIRECTORY_SEPARATOR;
        $prelossDir = $imagesRoot . 'preloss';
        $normImages = strtolower(str_replace('\\', '/', rtrim($imagesRoot, '/\\'))) . '/';

        $candidates = [];
        $candidates[] = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $stored);

        if (str_starts_with($lower, 'uploads/images/')) {
            $tail = substr($stored, strlen('uploads/images/'));
            $candidates[] = $imagesRoot . str_replace('/', DIRECTORY_SEPARATOR, $tail);
        }
        if (str_starts_with($lower, 'preloss/')) {
            $candidates[] = $imagesRoot . str_replace('/', DIRECTORY_SEPARATOR, $stored);
        }
        $candidates[] = $prelossDir . DIRECTORY_SEPARATOR . $base;

        foreach ($candidates as $c) {
            if ($c === '') {
                continue;
            }
            $normC = strtolower(str_replace('\\', '/', $c));
            if (!str_starts_with($normC, $normImages)) {
                continue;
            }
            if (is_file($c) && is_readable($c)) {
                return $c;
            }
        }
    }

    return null;
}
