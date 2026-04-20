<?php

declare(strict_types=1);

require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'site_roots.php';

/**
 * Resolve Document.imagePath (must stay under uploads/images/) to an absolute readable file path.
 */
function ds_document_resolve_uploaded_file(string $storedFilePath, string $projectRoot): ?string
{
    $stored = ltrim(str_replace('\\', '/', trim($storedFilePath)), '/');
    if ($stored === '' || str_contains($stored, '..')) {
        return null;
    }
    if (!str_starts_with(strtolower($stored), 'uploads/images/')) {
        return null;
    }

    foreach (ds_api_site_roots($projectRoot) as $root) {
        $full = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $stored);
        $imagesRoot = $root . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'images' . DIRECTORY_SEPARATOR;
        $normImages = strtolower(str_replace('\\', '/', rtrim($imagesRoot, '/\\'))) . '/';
        $normFull = strtolower(str_replace('\\', '/', $full));
        if (!str_starts_with($normFull, $normImages)) {
            continue;
        }
        if (is_file($full) && is_readable($full)) {
            return $full;
        }
    }

    return null;
}
