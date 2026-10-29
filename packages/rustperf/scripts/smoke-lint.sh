#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/rustperf-lint"
cargo build -q --release
BIN="$ROOT/rustperf-lint/target/release/rustperf-lint"
set +e
"$BIN" "$ROOT/rustperf-lint/fixtures/bad" \
  --severity rs-alloc-hot=error --severity rs-println-hot=error --severity rs-format-rebind-hot=error --severity rs-collect-vec-hot=error
b=$?
"$BIN" "$ROOT/rustperf-lint/fixtures/good"
g=$?
"$BIN" "$ROOT/rustperf-lint/fixtures/bad/rs-alloc-hot_clone_loop.rs"
h=$?
# default rs-format-rebind-hot=error: bad format-rebind fixture alone must exit 1
"$BIN" "$ROOT/rustperf-lint/fixtures/bad/rs-format-rebind-hot_format_rebind.rs"
e4=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
[[ "$e4" -eq 1 ]] || { echo "rs-format-rebind-hot bad should exit 1, got $e4"; exit 1; }
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
check_pair rs-map-new-hot "$ROOT/rustperf-lint/fixtures/bad/rs-map-new-hot_map_loop.rs" "$ROOT/rustperf-lint/fixtures/good/rs-map-new-hot_map_once.rs"
check_pair rs-regex-new-hot "$ROOT/rustperf-lint/fixtures/bad/rs-regex-new-hot_regex_loop.rs" "$ROOT/rustperf-lint/fixtures/good/rs-regex-new-hot_pattern_varies.rs"
check_pair rs-file-open-hot "$ROOT/rustperf-lint/fixtures/bad/rs-file-open-hot_open_loop.rs" "$ROOT/rustperf-lint/fixtures/good/rs-file-open-hot_path_varies.rs"
check_pair rs-clock-hot "$ROOT/rustperf-lint/fixtures/bad/rs-clock-hot_clock_loop.rs" "$ROOT/rustperf-lint/fixtures/good/rs-clock-hot_await_loop.rs"
echo "rustperf-lint smoke ok"
