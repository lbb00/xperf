<?php
/** One-shot merge where LHS is not the growing accumulator pattern across iterations of same list — 
 *  $links = array_merge($links, $extra) once per package is still same-var; use distinct temps. */
function mergeRequires(array $links, array $dev): array {
    return array_merge($links, $dev); // not in loop
}
