#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/objcperf-lint"
make -s
BIN="$ROOT/objcperf-lint/objcperf-lint"
set +e
"$BIN" "$ROOT/objcperf-lint/fixtures/bad" \
  --severity oc-nsstring-append-in-loop=error --severity oc-nslog-in-loop=error
b=$?
"$BIN" "$ROOT/objcperf-lint/fixtures/good"
g=$?
"$BIN" "$ROOT/objcperf-lint/fixtures/good" --strict-hints \
  --severity oc-nsstring-append-in-loop=hint --severity oc-nslog-in-loop=hint
gs=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$gs" -eq 0 ]] || { echo "good strict-hints should exit 0, got $gs"; exit 1; }
out=$("$BIN" "$ROOT/objcperf-lint/fixtures/bad" --format json --no-fail --severity oc-nsstring-append-in-loop=hint --severity oc-nslog-in-loop=hint)
echo "$out" | grep -q '"oc-nsstring-append-in-loop"' || { echo "should report oc-nsstring-append-in-loop"; exit 1; }
echo "$out" | grep -q '"oc-nslog-in-loop"' || { echo "should report oc-nslog-in-loop"; exit 1; }

check_pair() {
  local rule="$1" badf="$2" goodf="$3"
  set +e
  "$BIN" "$badf" --severity "${rule}=error"
  local be=$?
  "$BIN" "$goodf" --strict-hints \
    --severity oc-nsstring-append-in-loop=hint \
    --severity oc-nslog-in-loop=hint
  local ge=$?
  "$BIN" "$badf"
  local he=$?
  "$BIN" "$badf" --strict-hints
  local se=$?
  set -e
  [[ "$be" -eq 1 ]] || { echo "$rule bad should exit 1, got $be"; exit 1; }
  [[ "$ge" -eq 0 ]] || { echo "$rule good should exit 0, got $ge"; exit 1; }
  [[ "$he" -eq 0 ]] || { echo "$rule default hint should exit 0, got $he"; exit 1; }
  [[ "$se" -eq 1 ]] || { echo "$rule strict-hints should exit 1, got $se"; exit 1; }
  local fired
  fired=$("$BIN" "$badf" --format json --no-fail \
    --severity oc-nsstring-append-in-loop=error \
    --severity oc-nslog-in-loop=error \
    --severity oc-dateformatter-in-loop=error \
    --severity oc-json-in-loop=error \
    --severity oc-regex-in-loop=error)
  echo "$fired" | grep -q "\"rule\":\"${rule}\"" || { echo "$rule bad did not report $rule"; exit 1; }
  local other
  for other in oc-nsstring-append-in-loop oc-nslog-in-loop oc-dateformatter-in-loop oc-json-in-loop oc-regex-in-loop; do
    [[ "$other" == "$rule" ]] && continue
    if echo "$fired" | grep -q "\"rule\":\"${other}\""; then
      echo "$rule bad also fired $other"
      exit 1
    fi
  done
}

check_pair oc-dateformatter-in-loop \
  "$ROOT/objcperf-lint/fixtures/bad/oc-dateformatter-in-loop_alloc_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-dateformatter-in-loop_once.m"
check_pair oc-json-in-loop \
  "$ROOT/objcperf-lint/fixtures/bad/oc-json-in-loop_json_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-json-in-loop_json_once.m"
check_pair oc-regex-in-loop \
  "$ROOT/objcperf-lint/fixtures/bad/oc-regex-in-loop_regex_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-regex-in-loop_regex_once.m"
check_pair oc-file-read-in-loop \
  "$ROOT/objcperf-lint/fixtures/bad/oc-file-read-in-loop_read_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-file-read-in-loop_read_once.m"
check_pair oc-clock-in-loop \
  "$ROOT/objcperf-lint/fixtures/bad/oc-clock-in-loop_clock_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-clock-in-loop_clock_once.m"
check_pair oc-value-for-key-in-loop \
  "$ROOT/objcperf-lint/fixtures/bad/oc-value-for-key-in-loop_key_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-value-for-key-in-loop_key_once.m"
echo "objcperf-lint smoke ok"
