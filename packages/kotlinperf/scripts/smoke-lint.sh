#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v kotlinc >/dev/null 2>&1; then
  if [[ -x /opt/kotlin/kotlinc/bin/kotlinc ]]; then
    export PATH="/opt/kotlin/kotlinc/bin:$PATH"
  else
    echo "kotlinperf-lint smoke SKIP (no kotlinc); fixtures present"
    ls "$ROOT/kotlinperf-lint/fixtures/bad" "$ROOT/kotlinperf-lint/fixtures/good" >/dev/null
    exit 0
  fi
fi
bash "$ROOT/kotlinperf-lint/build.sh"
BIN="$ROOT/kotlinperf-lint/kotlinperf-lint"
set +e
"$BIN" "$ROOT/kotlinperf-lint/fixtures/bad" \
  --severity kt-list-add-in-loop=error --severity kt-string-plus-in-loop=error --severity kt-println-in-loop=error
b=$?
"$BIN" "$ROOT/kotlinperf-lint/fixtures/good"
g=$?
"$BIN" "$ROOT/kotlinperf-lint/fixtures/bad/kt-list-add-in-loop_list_loop.kt" --severity kt-list-add-in-loop=hint
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
out=$("$BIN" "$ROOT/kotlinperf-lint/fixtures/bad" --format json --no-fail --severity kt-list-add-in-loop=hint --severity kt-string-plus-in-loop=hint --severity kt-println-in-loop=hint)
echo "$out" | grep -q '"kt-list-add-in-loop"\|"kt-string-plus-in-loop"\|"kt-println-in-loop"' || { echo "default should report a slug rule"; exit 1; }
echo "kotlinperf-lint smoke ok"
