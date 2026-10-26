<?php
function cat(array $parts): string {
    $s = '';
    foreach ($parts as $p) {
        $s .= $p;
    }
    return $s;
}
