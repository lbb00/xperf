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
  --severity kt-list-add-hot=error --severity kt-string-plus-hot=error --severity kt-println-hot=error
b=$?
"$BIN" "$ROOT/kotlinperf-lint/fixtures/good"
g=$?
"$BIN" "$ROOT/kotlinperf-lint/fixtures/bad/kt-list-add-hot_list_loop.kt" --severity kt-list-add-hot=hint
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
out=$("$BIN" "$ROOT/kotlinperf-lint/fixtures/bad" --format json --no-fail --severity kt-list-add-hot=hint --severity kt-string-plus-hot=hint --severity kt-println-hot=hint)
echo "$out" | grep -q '"kt-list-add-hot"\|"kt-string-plus-hot"\|"kt-println-hot"' || { echo "default should report a slug rule"; exit 1; }
echo "kotlinperf-lint smoke ok"
