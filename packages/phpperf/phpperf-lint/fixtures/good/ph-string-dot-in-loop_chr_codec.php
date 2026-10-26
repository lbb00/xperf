<?php
function utf8bytes(array $codes): string {
    $string = '';
    foreach ($codes as $code) {
        $string .= chr($code & 0xFF);
    }
    return $string;
}
