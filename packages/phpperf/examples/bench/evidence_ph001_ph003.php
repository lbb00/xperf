#!/usr/bin/env php
<?php
declare(strict_types=1);
/** Evidence for ph-string-dot-in-loop / ph-echo-in-loop → packages/phpperf/evidence/ */

$ROUNDS = (int) (getenv('PH_ROUNDS') ?: '9');
$WARM = (int) (getenv('PH_WARM') ?: '3');
$scriptDir = dirname(__FILE__);
$OUT = getenv('EVIDENCE_DIR') ?: ($scriptDir . '/../../evidence');

function median(array $xs): float {
    sort($xs, SORT_NUMERIC);
    $n = count($xs);
    if ($n === 0) return 0.0;
    if ($n % 2 === 1) return (float) $xs[intdiv($n, 2)];
    return 0.5 * ((float) $xs[$n / 2 - 1] + (float) $xs[$n / 2]);
}

function time_many(callable $fn, int $warm, int $rounds): float {
    for ($i = 0; $i < $warm; $i++) $fn();
    $samples = [];
    $sink = 0;
    for ($r = 0; $r < $rounds; $r++) {
        if (function_exists('gc_collect_cycles')) gc_collect_cycles();
        $t0 = hrtime(true);
        $sink += $fn();
        $t1 = hrtime(true);
        $samples[] = ($t1 - $t0) / 1e6;
    }
    return median($samples);
}

$ver = 'PHP ' . PHP_VERSION;
$ts = gmdate('Y-m-d\TH:i:s\Z');
$lines = [];
$emit = function (string $rule, string $case, string $role, float $med, int $ops, float $ratio) use (&$lines, $ver, $ts): void {
    $lines[] = [$rule, sprintf(
        '{"rule":"%s","case":"%s","role":"%s","php":"%s","median_ms":%.6f,"ops":%d,"ratio":%.6f,"ts":"%s"}',
        $rule, $case, $role, $ver, $med, $ops, $ratio, $ts
    )];
    fwrite(STDERR, sprintf("  %s %s %s median=%.3f ms ops=%d ratio=%.3f\n", $rule, $role, $case, $med, $ops, $ratio));
};

// ph-string-dot-in-loop .= vs implode
$n1 = (int) (getenv('PH001_N') ?: '50000');
$parts = array_fill(0, $n1, 'x');
fwrite(STDERR, "ph-string-dot-in-loop str-dot n={$n1}\n");
$med1a = time_many(fn () => strlen(implode('', $parts)), $WARM, $ROUNDS);
$med1b = time_many(function () use ($parts) {
    $s = '';
    foreach ($parts as $p) $s .= $p;
    return strlen($s);
}, $WARM, $ROUNDS);
$emit('ph-string-dot-in-loop', 'implode', 'after', $med1a, $n1, 1.0);
$emit('ph-string-dot-in-loop', 'str_dot', 'before', $med1b, $n1, $med1b / max($med1a, 1e-9));

$n1s = (int) (getenv('PH001_N_SMALL') ?: '100');
$partsS = array_slice($parts, 0, $n1s);
$med1sa = time_many(fn () => strlen(implode('', $partsS)), $WARM, $ROUNDS);
$med1sb = time_many(function () use ($partsS) {
    $s = '';
    foreach ($partsS as $p) $s .= $p;
    return strlen($s);
}, $WARM, $ROUNDS);
$emit('ph-string-dot-in-loop', 'small_implode', 'after', $med1sa, $n1s, 1.0);
$emit('ph-string-dot-in-loop', 'small_str_dot', 'before', $med1sb, $n1s, $med1sb / max($med1sa, 1e-9));

// ph-echo-in-loop echo in loop vs implode once (to /dev/null)
$n3 = (int) (getenv('PH003_N') ?: '20000');
fwrite(STDERR, "ph-echo-in-loop echo-loop n={$n3}\n");
$med3a = time_many(function () use ($n3) {
    $buf = [];
    for ($i = 0; $i < $n3; $i++) $buf[] = (string)$i;
    $out = fopen('/dev/null', 'w');
    fwrite($out, implode("\n", $buf) . "\n");
    fclose($out);
    return $n3;
}, $WARM, $ROUNDS);
$med3b = time_many(function () use ($n3) {
    $out = fopen('/dev/null', 'w');
    for ($i = 0; $i < $n3; $i++) {
        fwrite($out, $i . "\n");
    }
    fclose($out);
    return $n3;
}, $WARM, $ROUNDS);
$emit('ph-echo-in-loop', 'implode_once', 'after', $med3a, $n3, 1.0);
$emit('ph-echo-in-loop', 'echo_each_iter', 'before', $med3b, $n3, $med3b / max($med3a, 1e-9));

foreach (['ph-string-dot-in-loop', 'ph-echo-in-loop'] as $rule) {
    $body = '';
    foreach ($lines as [$r, $obj]) {
        if ($r === $rule) $body .= $obj . "\n";
    }
    $path = rtrim($OUT, '/') . "/{$rule}.jsonl";
    file_put_contents($path, $body);
    fwrite(STDERR, "wrote {$path}\n");
    echo $body;
}
