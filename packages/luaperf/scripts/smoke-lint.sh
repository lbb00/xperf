#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN=(lua "$ROOT/luaperf-lint/luaperf-lint.lua")
set +e
"${BIN[@]}" "$ROOT/luaperf-lint/fixtures/bad" --severity lu-table-insert-hot=error --severity lu-string-concat-hot=error --severity lu-print-hot=error
b=$?
"${BIN[@]}" "$ROOT/luaperf-lint/fixtures/good"
g=$?
"${BIN[@]}" "$ROOT/luaperf-lint/fixtures/bad/lu-table-insert-hot_insert_loop.lua"
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
echo "luaperf-lint smoke ok"
