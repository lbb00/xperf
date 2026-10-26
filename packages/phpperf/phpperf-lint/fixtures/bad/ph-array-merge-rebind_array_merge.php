<?php
function grow(array $items): array {
    $a = [];
    foreach ($items as $x) {
        $a = array_merge($a, [$x]);
    }
    return $a;
}
