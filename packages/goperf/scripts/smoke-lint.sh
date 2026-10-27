#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/goperf-lint/goperf-lint"
(cd "$ROOT/goperf-lint" && go build -o goperf-lint ./cmd/goperf-lint)
set +e
"$BIN" "$ROOT/goperf-lint/fixtures/bad" \
  --severity gp-make-hot=error --severity gp-string-plus-hot=error --severity gp-fmt-hot=error \
  --severity gp-append-nil-slice=error --severity gp-defer-hot=error
b=$?
"$BIN" "$ROOT/goperf-lint/fixtures/good"
g=$?
"$BIN" "$ROOT/goperf-lint/fixtures/bad/gp-append-nil-slice_append_grow.go"
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad fixtures should exit 1 with error severity, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good fixtures should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "default hint should exit 0, got $h"; exit 1; }
# Defaults must fire gp-append-nil-slice/gp-defer-hot on bad fixtures (hint)
out=$("$BIN" "$ROOT/goperf-lint/fixtures/bad" --format json --no-fail)
echo "$out" | grep -q '"gp-append-nil-slice"' || { echo "default should report gp-append-nil-slice"; exit 1; }
echo "$out" | grep -q '"gp-defer-hot"' || { echo "default should report gp-defer-hot"; exit 1; }
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
check_pair gp-regexp-compile-hot "$ROOT/goperf-lint/fixtures/bad/gp-regexp-compile-hot_compile_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-regexp-compile-hot_pattern_varies.go"
check_pair gp-json-marshal-hot "$ROOT/goperf-lint/fixtures/bad/gp-json-marshal-hot_marshal_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-json-marshal-hot_value_varies.go"
check_pair gp-reflect-hot "$ROOT/goperf-lint/fixtures/bad/gp-reflect-hot_reflect_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-reflect-hot_quiet.go"
check_pair gp-os-open-hot "$ROOT/goperf-lint/fixtures/bad/gp-os-open-hot_open_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-os-open-hot_path_varies.go"
check_pair gp-time-now-hot "$ROOT/goperf-lint/fixtures/bad/gp-time-now-hot_now_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-time-now-hot_quiet.go"
echo "goperf-lint smoke ok"
