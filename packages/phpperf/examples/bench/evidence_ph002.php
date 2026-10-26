#!/usr/bin/env php
<?php
/**
 * Evidence microbench for ph-array-merge-rebind → packages/phpperf/evidence/ph-array-merge-rebind.jsonl
 * Smell: $a = array_merge($a, …) rebind in loop; fix: $a[] = / array_push.
 * Timer: hrtime(true) wall ns; warm=3; median of ≥9; GC collect before samples.
 */

declare(strict_types=1);

$ROUNDS = (int) (getenv('PH002_ROUNDS') ?: '9');
$WARM = (int) (getenv('PH002_WARM') ?: '3');
$N_SCALAR = (int) (getenv('PH002_N_SCALAR') ?: '20000');
$N_CHUNK = (int) (getenv('PH002_N_CHUNK') ?: '5000');
$CHUNK_LEN = (int) (getenv('PH002_CHUNK_LEN') ?: '8');
$N_SMALL = (int) (getenv('PH002_N_SMALL') ?: '100');

$scriptDir = dirname(__FILE__);
$OUT = getenv('EVIDENCE_DIR') ?: ($scriptDir . '/../../evidence');

function median(array $xs): float
{
    sort($xs, SORT_NUMERIC);
    $n = count($xs);
    if ($n === 0) {
        return 0.0;
    }
    if ($n % 2 === 1) {
        return (float) $xs[intdiv($n, 2)];
    }
    return 0.5 * ((float) $xs[$n / 2 - 1] + (float) $xs[$n / 2]);
}

/** @param callable():int $fn */
function time_many(callable $fn, int $warm, int $rounds): float
{
    for ($i = 0; $i < $warm; $i++) {
        $fn();
    }
    $samples = [];
    $sink = 0;
    for ($r = 0; $r < $rounds; $r++) {
        if (function_exists('gc_collect_cycles')) {
            gc_collect_cycles();
        }
        $t0 = hrtime(true);
        $sink += $fn();
        $t1 = hrtime(true);
        $samples[] = ($t1 - $t0) / 1e6; // ms
    }
    if ($sink !== $sink) {
        fwrite(STDERR, "nan sink\n");
        exit(1);
    }
    return median($samples);
}

// Pair A: fixture-shaped — single-element array_merge rebind vs $a[] =
function case_scalar_merge(int $n): int
{
    $a = [];
    for ($i = 0; $i < $n; $i++) {
        $a = array_merge($a, [$i]);
    }
    return count($a);
}

function case_scalar_push(int $n): int
{
    $a = [];
    for ($i = 0; $i < $n; $i++) {
        $a[] = $i;
    }
    return count($a);
}

// Pair B: merge fixed-size chunks each iteration (common Composer/Laravel shape)
function case_chunk_merge(int $n, int $chunkLen): int
{
    $chunk = range(0, $chunkLen - 1);
    $a = [];
    for ($i = 0; $i < $n; $i++) {
        $a = array_merge($a, $chunk);
    }
    return count($a);
}

function case_chunk_push(int $n, int $chunkLen): int
{
    $chunk = range(0, $chunkLen - 1);
    $a = [];
    for ($i = 0; $i < $n; $i++) {
        foreach ($chunk as $x) {
            $a[] = $x;
        }
    }
    return count($a);
}

function php_id(): string
{
    return 'PHP ' . PHP_VERSION;
}

function iso_ts_utc(): string
{
    return gmdate('Y-m-d\TH:i:s\Z');
}

$ver = php_id();
$ts = iso_ts_utc();
$lines = [];

$emit = function (string $case, string $role, float $med, int $ops, float $ratio) use (&$lines, $ver, $ts): void {
    $lines[] = sprintf(
        '{"rule":"ph-array-merge-rebind","case":"%s","role":"%s","php":"%s","median_ms":%.6f,"ops":%d,"ratio":%.6f,"ts":"%s"}',
        $case,
        $role,
        $ver,
        $med,
        $ops,
        $ratio,
        $ts
    );
    fwrite(STDERR, sprintf("  %s %s median=%.3f ms ops=%d ratio=%.3f\n", $role, $case, $med, $ops, $ratio));
};

fwrite(STDERR, sprintf(
    "ph-array-merge-rebind evidence: %s warm=%d rounds=%d N_scalar=%d N_chunk=%d chunk_len=%d N_small=%d\n",
    $ver,
    $WARM,
    $ROUNDS,
    $N_SCALAR,
    $N_CHUNK,
    $CHUNK_LEN,
    $N_SMALL
));

fwrite(STDERR, "-- pair A scalar (fixture-shaped array_merge([\$x]) vs \$a[])\n");
$med_sa = time_many(fn () => case_scalar_push($N_SCALAR), $WARM, $ROUNDS);
$med_sb = time_many(fn () => case_scalar_merge($N_SCALAR), $WARM, $ROUNDS);
$emit('scalar_push', 'after', $med_sa, $N_SCALAR, 1.0);
$emit('scalar_array_merge', 'before', $med_sb, $N_SCALAR, $med_sb / max($med_sa, 1e-9));

fwrite(STDERR, "-- pair B chunk merge (len={$CHUNK_LEN})\n");
$med_ca = time_many(fn () => case_chunk_push($N_CHUNK, $CHUNK_LEN), $WARM, $ROUNDS);
$med_cb = time_many(fn () => case_chunk_merge($N_CHUNK, $CHUNK_LEN), $WARM, $ROUNDS);
$emit('chunk8_push', 'after', $med_ca, $N_CHUNK, 1.0);
$emit('chunk8_array_merge', 'before', $med_cb, $N_CHUNK, $med_cb / max($med_ca, 1e-9));

fwrite(STDERR, "-- pair C small N\n");
$med_sma = time_many(fn () => case_scalar_push($N_SMALL), $WARM, $ROUNDS);
$med_smb = time_many(fn () => case_scalar_merge($N_SMALL), $WARM, $ROUNDS);
$emit('small_n_push', 'after', $med_sma, $N_SMALL, 1.0);
$emit('small_n_array_merge', 'before', $med_smb, $N_SMALL, $med_smb / max($med_sma, 1e-9));

$outPath = rtrim($OUT, '/') . '/ph-array-merge-rebind.jsonl';
file_put_contents($outPath, implode("\n", $lines) . "\n");
fwrite(STDERR, "wrote {$outPath}\n");
foreach ($lines as $line) {
    echo $line, "\n";
}
