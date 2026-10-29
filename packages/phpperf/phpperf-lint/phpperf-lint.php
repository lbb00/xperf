#!/usr/bin/env php
<?php
declare(strict_types=1);

const MSG = [
    'ph-string-dot-hot' => 'string .=; prefer implode / collector — cost adds up even off a hot path',
    'ph-array-merge-rebind' => 'array_merge rebinding; prefer $a[] =  — cost adds up even off a hot path',
    'ph-echo-hot' => 'echo/print; gate or buffer — cost adds up even off a hot path',
];

$sev = ['ph-string-dot-hot' => 'off', 'ph-array-merge-rebind' => 'error', 'ph-echo-hot' => 'hint'];
$format = 'text';
$strictHints = false;
$noFail = false;
$scope = 'all';
$paths = [];

$argv = array_slice($argv, 1);
for ($i = 0; $i < count($argv); $i++) {
    $a = $argv[$i];
    if ($a === '-h' || $a === '--help') { usage(0); }
    if ($a === '--format' && isset($argv[$i + 1])) { $format = $argv[++$i]; continue; }
    if (str_starts_with($a, '--format=')) { $format = substr($a, 9); continue; }
    if ($a === '--severity' && isset($argv[$i + 1])) { apply_sev($sev, $argv[++$i]); continue; }
    if (str_starts_with($a, '--severity=')) { apply_sev($sev, substr($a, 11)); continue; }
    if ($a === '--strict-hints') { $strictHints = true; continue; }
    if ($a === '--no-fail') { $noFail = true; continue; }
    if ($a === '--scope' && isset($argv[$i + 1])) { $scope = $argv[++$i]; if ($scope !== 'all' && $scope !== 'loop') usage(2); continue; }
    if (str_starts_with($a, '--scope=')) { $scope = substr($a, 8); if ($scope !== 'all' && $scope !== 'loop') usage(2); continue; }
    if (str_starts_with($a, '-')) { usage(2); }
    $paths[] = $a;
}
if (!$paths) usage(2);

$findings = [];
foreach ($paths as $p) {
    foreach (scan_path($p, $scope) as $f) {
        $findings[] = $f;
    }
}

$nerr = 0; $nhint = 0;
$rows = []; $lines = [];
foreach ($findings as $f) {
    $level = $sev[$f['rule']] ?? 'hint';
    if ($level === 'off') continue;
    if ($level === 'error') $nerr++; else $nhint++;
    if ($format === 'json') {
        $rows[] = [
            'rule' => $f['rule'], 'severity' => $level,
            'path' => $f['path'], 'line' => $f['line'], 'message' => $f['message'],
        ];
    } else {
        $lines[] = sprintf('%s:%d: %s %s: %s', $f['path'], $f['line'], $level, $f['rule'], $f['message']);
    }
}
if ($format === 'json') {
    fwrite(STDOUT, json_encode($rows) . "\n");
} else {
    if ($lines) fwrite(STDOUT, implode("\n", $lines) . "\n");
    $shown = $nerr + $nhint;
    if ($shown) fwrite(STDERR, sprintf("%d finding(s) (%d error, %d hint)\n", $shown, $nerr, $nhint));
    else fwrite(STDERR, "ok\n");
}
if ($noFail) exit(0);
exit(($nerr > 0 || ($strictHints && $nhint > 0)) ? 1 : 0);

function apply_sev(array &$sev, string $spec): void {
    $eq = strpos($spec, '=');
    if ($eq === false) usage(2);
    $rule = substr($spec, 0, $eq);
    $level = substr($spec, $eq + 1);
    if (!isset($sev[$rule]) || !in_array($level, ['off', 'hint', 'error'], true)) usage(2);
    $sev[$rule] = $level;
}

function usage(int $code): void {
    fwrite(STDERR, "Usage: phpperf-lint.php PATH... [options]\n"
        . "  --format text|json\n"
        . "  --severity RULE=error|hint|off\n"
        . "  --scope all|loop   (default: all)\n"
        . "  --strict-hints\n"
        . "  --no-fail\n");
    exit($code);
}

function strip_comment(string $line): string {
    $in = null;
    $len = strlen($line);
    for ($i = 0; $i < $len; $i++) {
        $c = $line[$i];
        if ($in !== null) {
            if ($c === '\\' && $i + 1 < $len) { $i++; continue; }
            if ($c === $in) $in = null;
            continue;
        }
        if ($c === '"' || $c === "'") { $in = $c; continue; }
        if ($c === '/' && $i + 1 < $len && $line[$i + 1] === '/') return substr($line, 0, $i);
        if ($c === '#') return substr($line, 0, $i);
    }
    return $line;
}

/** Blank string literals so \becho\b inside paths/URLs does not match. */
function mask_strings(string $code): string {
    return preg_replace('/"(?:\\\\.|[^"\\\\])*"|\'(?:\\\\.|[^\'\\\\])*\'/', '""', $code) ?? $code;
}

function scan_file(string $path, string $scope = "all"): array {
    $scopeMode = $scope === "loop" ? "loop" : "all";
    $text = @file_get_contents($path);
    if ($text === false) return [];
    $lines = preg_split("/\r\n|\n|\r/", $text);
    $out = [];
    $depth = 0; $inLoop = 0;
    foreach ($lines as $idx => $raw) {
        $lineNo = $idx + 1;
        // Docblock / block-comment continuation lines — not executable.
        if (preg_match('/^\s*\*/', $raw)) {
            continue;
        }
        $code = strip_comment($raw);
        $masked = mask_strings($code);
        $opens = substr_count($code, '{');
        $closes = substr_count($code, '}');
        if (preg_match('/\b(for|foreach|while)\b/', $masked)) {
            $inLoop = $depth + 1;
        }
        $matchHere = $scopeMode === "all" ? true : ($inLoop > 0 && $depth >= $inLoop);
        if ($matchHere) {
            if (preg_match('/\.=/', $masked)) {
                // G3: tiny literal appends / chr codecs / sprintf message fragments — OK-idiom.
                $skipPh001 = false;
                if (preg_match('/\.=\s*[\'\"][^\'\"]{0,4}[\'\"]/', $code)) {
                    $skipPh001 = true;
                }
                if (preg_match('/\.=\s*\\\\chr\s*\(/', $masked) || preg_match('/\.=\s*chr\s*\(/', $masked)) {
                    $skipPh001 = true;
                }
                if (preg_match('/\$(message|text|msg|hint|error)\s*\.=/i', $masked)
                    && str_contains($masked, 'sprintf')) {
                    $skipPh001 = true;
                }
                if (!$skipPh001) {
                    $out[] = ['rule' => 'ph-string-dot-hot', 'path' => $path, 'line' => $lineNo, 'message' => MSG['ph-string-dot-hot']];
                }
            }
            // G3: require accumulator rebind $a = array_merge($a, ...)
            if (preg_match('/\$(\w+)\s*=\s*array_merge\s*\(\s*\$\1\s*,/', $masked)) {
                $out[] = ['rule' => 'ph-array-merge-rebind', 'path' => $path, 'line' => $lineNo, 'message' => MSG['ph-array-merge-rebind']];
            }
            // Statement-like echo/print only (not inside masked strings).
            if (preg_match('/(?:^|[;{])\s*(echo|print)\b/', $masked)) {
                $out[] = ['rule' => 'ph-echo-hot', 'path' => $path, 'line' => $lineNo, 'message' => MSG['ph-echo-hot']];
            }
        }
        $depth += $opens - $closes;
        if ($depth < 0) $depth = 0;
        if ($inLoop > 0 && $depth < $inLoop) $inLoop = 0;
    }
    return $out;
}

function skip_dir_name(string $name): bool {
    static $skip = [
        '.git' => true, 'fixtures' => true, 'vendor' => true, 'node_modules' => true,
        'test' => true, 'tests' => true, 'Tests' => true, 'Fixtures' => true,
        'views' => true, // Blade / ErrorHandler HTML templates — echo-heavy by design
        'Tui' => true,   // G3: terminal paint .= is intentional
        'bench' => true, // G4: evidence harnesses under examples/bench/
        'benchmark' => true,
        '.github' => true, // G3: CI / packaging scripts
    ];
    return isset($skip[$name]);
}

function scan_path(string $root, string $scope = "all"): array {
    if (is_file($root)) {
        return str_ends_with($root, '.php') ? scan_file($root, $scope) : [];
    }
    $all = [];
    $it = new RecursiveIteratorIterator(
        new RecursiveCallbackFilterIterator(
            new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
            function ($current, $key, $iterator) {
                if ($current->isDir()) {
                    return !skip_dir_name($current->getFilename());
                }
                return true;
            }
        )
    );
    foreach ($it as $file) {
        if ($file->isFile() && str_ends_with($file->getFilename(), '.php')) {
            $pathname = $file->getPathname();
            // Codegen / intl dump scripts under Resources/bin — not app hot path.
            if (str_contains($pathname, '/Resources/bin/') || str_contains($pathname, '/resources/bin/')) {
                continue;
            }
            // G3 reverse-opt: framework codegen / UTF codecs / dumpers — OK-idiom builders.
            if (str_contains($pathname, '/JsonStreamer/Write/')
                || str_contains($pathname, '/VarExporter/')
                || str_contains($pathname, '/VarDumper/')
                || str_contains($pathname, 'AbstractUnicodeString.php')
                || str_contains($pathname, 'ByteString.php')
                || str_contains($pathname, 'UnicodeString.php')
                || str_contains($pathname, 'JsonFormatter.php')
                || str_contains($pathname, 'AutoloadGenerator.php')
                || str_contains($pathname, 'DiagnoseCommand.php')
                || str_contains($pathname, '/Compiler.php') && str_contains($pathname, '/Composer/')) {
                continue;
            }
            foreach (scan_file($pathname, $scope) as $f) {
                $all[] = $f;
            }
        }
    }
    return $all;
}
