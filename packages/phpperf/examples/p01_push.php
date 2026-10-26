<?php
function collect(int $n): array {
    $out = [];
    for ($i = 0; $i < $n; $i++) {
        $out[] = $i;
    }
    return $out;
}

var_export(collect(3));
