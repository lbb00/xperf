<?php
function dump(int $n): void {
    $buf = [];
    for ($i = 0; $i < $n; $i++) {
        $buf[] = (string)$i;
    }
    echo implode("\n", $buf), "\n";
}
