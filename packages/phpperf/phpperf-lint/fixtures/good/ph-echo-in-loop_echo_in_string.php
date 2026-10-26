<?php
function topics(array $channels): array {
    $out = [];
    foreach ($channels as $channel) {
        $out[] = 'https://example.alt/echo/channel/' . $channel;
    }
    return $out;
}
