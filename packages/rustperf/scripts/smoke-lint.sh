#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/rustperf-lint"
cargo build -q --release
BIN="$ROOT/rustperf-lint/target/release/rustperf-lint"
set +e
"$BIN" "$ROOT/rustperf-lint/fixtures/bad" \
  --severity rs-alloc-in-loop=error --severity rs-println-in-loop=error --severity rs-format-rebind-in-loop=error --severity rs-collect-vec-in-loop=error
b=$?
"$BIN" "$ROOT/rustperf-lint/fixtures/good"
g=$?
"$BIN" "$ROOT/rustperf-lint/fixtures/bad/rs-alloc-in-loop_clone_loop.rs"
h=$?
# default rs-format-rebind-in-loop=error: bad format-rebind fixture alone must exit 1
"$BIN" "$ROOT/rustperf-lint/fixtures/bad/rs-format-rebind-in-loop_format_rebind.rs"
e4=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
[[ "$e4" -eq 1 ]] || { echo "rs-format-rebind-in-loop bad should exit 1, got $e4"; exit 1; }
check_pair() {
  local rule="$1" badf="$2" goodf="$3"
  set +e
  "$BIN" "$badf" --severity "${rule}=error"
  local be=$?
  "$BIN" "$goodf" --strict-hints
  local ge=$?
  set -e
  [[ "$be" -eq 1 ]] || { echo "$rule bad should exit 1, got $be"; exit 1; }
  [[ "$ge" -eq 0 ]] || { echo "$rule good should exit 0, got $ge"; exit 1; }
}
check_pair rs-map-new-in-loop "$ROOT/rustperf-lint/fixtures/bad/rs-map-new-in-loop_map_loop.rs" "$ROOT/rustperf-lint/fixtures/good/rs-map-new-in-loop_map_once.rs"
check_pair rs-regex-new-in-loop "$ROOT/rustperf-lint/fixtures/bad/rs-regex-new-in-loop_regex_loop.rs" "$ROOT/rustperf-lint/fixtures/good/rs-regex-new-in-loop_regex_once.rs"
check_pair rs-file-open-in-loop "$ROOT/rustperf-lint/fixtures/bad/rs-file-open-in-loop_open_loop.rs" "$ROOT/rustperf-lint/fixtures/good/rs-file-open-in-loop_open_once.rs"
check_pair rs-clock-in-loop "$ROOT/rustperf-lint/fixtures/bad/rs-clock-in-loop_clock_loop.rs" "$ROOT/rustperf-lint/fixtures/good/rs-clock-in-loop_clock_once.rs"
echo "rustperf-lint smoke ok"
