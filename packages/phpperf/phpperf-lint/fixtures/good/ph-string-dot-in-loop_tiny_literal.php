<?php
/** Tiny literal .= in a loop is OK-idiom (G3); no variable builder. */
function commas(int $n): string {
    $s = 'x';
    for ($i = 0; $i < $n; $i++) {
        $s .= ',';
    }
    return $s;
}
