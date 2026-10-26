#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/goperf-lint/goperf-lint"
(cd "$ROOT/goperf-lint" && go build -o goperf-lint ./cmd/goperf-lint)
set +e
"$BIN" "$ROOT/goperf-lint/fixtures/bad" \
  --severity gp-make-in-loop=error --severity gp-string-plus-in-loop=error --severity gp-fmt-in-loop=error \
  --severity gp-append-nil-slice=error --severity gp-defer-in-loop=error
b=$?
"$BIN" "$ROOT/goperf-lint/fixtures/good"
g=$?
"$BIN" "$ROOT/goperf-lint/fixtures/bad/gp-append-nil-slice_append_grow.go"
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad fixtures should exit 1 with error severity, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good fixtures should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "default hint should exit 0, got $h"; exit 1; }
# Defaults must fire gp-append-nil-slice/gp-defer-in-loop on bad fixtures (hint)
out=$("$BIN" "$ROOT/goperf-lint/fixtures/bad" --format json --no-fail)
echo "$out" | grep -q '"gp-append-nil-slice"' || { echo "default should report gp-append-nil-slice"; exit 1; }
echo "$out" | grep -q '"gp-defer-in-loop"' || { echo "default should report gp-defer-in-loop"; exit 1; }
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
check_pair gp-regexp-compile-in-loop "$ROOT/goperf-lint/fixtures/bad/gp-regexp-compile-in-loop_compile_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-regexp-compile-in-loop_compile_once.go"
check_pair gp-json-marshal-in-loop "$ROOT/goperf-lint/fixtures/bad/gp-json-marshal-in-loop_marshal_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-json-marshal-in-loop_marshal_once.go"
check_pair gp-reflect-in-loop "$ROOT/goperf-lint/fixtures/bad/gp-reflect-in-loop_reflect_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-reflect-in-loop_reflect_once.go"
check_pair gp-os-open-in-loop "$ROOT/goperf-lint/fixtures/bad/gp-os-open-in-loop_open_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-os-open-in-loop_open_once.go"
check_pair gp-time-now-in-loop "$ROOT/goperf-lint/fixtures/bad/gp-time-now-in-loop_now_loop.go" "$ROOT/goperf-lint/fixtures/good/gp-time-now-in-loop_now_once.go"
echo "goperf-lint smoke ok"
