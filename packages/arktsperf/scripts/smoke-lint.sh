#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/arktsperf-lint/bin/arktsperf-lint.js"
set +e
node "$BIN" "$ROOT/arktsperf-lint/fixtures/bad" \
  --severity at-alloc-in-loop=error --severity at-console-in-loop=error \
  --severity at-includes-in-loop=error --severity at-json-in-loop=error
b=$?
node "$BIN" "$ROOT/arktsperf-lint/fixtures/good" --strict-hints
g=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
node "$BIN" "$ROOT/arktsperf-lint/fixtures/bad/at-includes-in-loop_includes_loop.ts" --no-fail 2>&1 | grep -q at-includes-in-loop \
  || { echo "at-includes-in-loop fixture must fire"; exit 1; }
node "$BIN" "$ROOT/arktsperf-lint/fixtures/bad/at-json-in-loop_json_loop.ts" --no-fail 2>&1 | grep -q at-json-in-loop \
  || { echo "at-json-in-loop fixture must fire"; exit 1; }
echo "arktsperf-lint smoke ok"
