<?php
function join_parts(array $parts): string {
    return implode('', $parts);
}

echo join_parts(['a', 'b', 'c']), PHP_EOL;
