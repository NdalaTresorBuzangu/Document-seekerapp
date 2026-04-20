<?php

declare(strict_types=1);

/**
 * Site roots to try when resolving `uploads/images/...` paths (project root vs document root).
 *
 * @return list<string>
 */
function ds_api_site_roots(string $projectRoot): array
{
    $out = [];
    $seen = [];
    $push = static function (string $p) use (&$out, &$seen): void {
        $p = rtrim(str_replace('\\', '/', trim($p)), '/');
        if ($p === '') {
            return;
        }
        $k = strtolower($p);
        if (isset($seen[$k])) {
            return;
        }
        $seen[$k] = true;
        $out[] = str_replace('/', DIRECTORY_SEPARATOR, $p);
    };

    $push($projectRoot);
    $rp = @realpath($projectRoot);
    if ($rp !== false && is_string($rp)) {
        $push($rp);
    }

    if (!empty($_SERVER['DOCUMENT_ROOT'])) {
        $dr = rtrim((string) $_SERVER['DOCUMENT_ROOT'], "/\\ \t");
        $push($dr);
        $drp = @realpath($dr);
        if ($drp !== false && is_string($drp)) {
            $push($drp);
        }
    }

    return $out;
}
