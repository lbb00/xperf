#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN=(php "$ROOT/phpperf-lint/phpperf-lint.php")
set +e
"${BIN[@]}" "$ROOT/phpperf-lint/fixtures/bad" --severity ph-string-dot-in-loop=error --severity ph-array-merge-rebind=error --severity ph-echo-in-loop=error
b=$?
"${BIN[@]}" "$ROOT/phpperf-lint/fixtures/good"
g=$?
"${BIN[@]}" "$ROOT/phpperf-lint/fixtures/bad/ph-string-dot-in-loop_str_dot.php"
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
echo "phpperf-lint smoke ok"
