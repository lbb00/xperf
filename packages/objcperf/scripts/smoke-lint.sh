#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/objcperf-lint"
make -s
BIN="$ROOT/objcperf-lint/objcperf-lint"
set +e
"$BIN" "$ROOT/objcperf-lint/fixtures/bad" \
  --severity oc-nsstring-append-hot=error --severity oc-nslog-hot=error
b=$?
"$BIN" "$ROOT/objcperf-lint/fixtures/good"
g=$?
"$BIN" "$ROOT/objcperf-lint/fixtures/good" --strict-hints \
  --severity oc-nsstring-append-hot=hint --severity oc-nslog-hot=hint
gs=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$gs" -eq 0 ]] || { echo "good strict-hints should exit 0, got $gs"; exit 1; }
out=$("$BIN" "$ROOT/objcperf-lint/fixtures/bad" --format json --no-fail --severity oc-nsstring-append-hot=hint --severity oc-nslog-hot=hint)
echo "$out" | grep -q '"oc-nsstring-append-hot"' || { echo "should report oc-nsstring-append-hot"; exit 1; }
echo "$out" | grep -q '"oc-nslog-hot"' || { echo "should report oc-nslog-hot"; exit 1; }

check_pair() {
  local rule="$1" badf="$2" goodf="$3"
  set +e
  "$BIN" "$badf" --severity "${rule}=error"
  local be=$?
  "$BIN" "$goodf" --strict-hints \
    --severity oc-nsstring-append-hot=hint \
    --severity oc-nslog-hot=hint
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
    --severity oc-nsstring-append-hot=error \
    --severity oc-nslog-hot=error \
    --severity oc-dateformatter-hot=error \
    --severity oc-json-hot=error \
    --severity oc-regex-hot=error)
  echo "$fired" | grep -q "\"rule\":\"${rule}\"" || { echo "$rule bad did not report $rule"; exit 1; }
  local other
  for other in oc-nsstring-append-hot oc-nslog-hot oc-dateformatter-hot oc-json-hot oc-regex-hot; do
    [[ "$other" == "$rule" ]] && continue
    if echo "$fired" | grep -q "\"rule\":\"${other}\""; then
      echo "$rule bad also fired $other"
      exit 1
    fi
  done
}

check_pair oc-dateformatter-hot \
  "$ROOT/objcperf-lint/fixtures/bad/oc-dateformatter-hot_alloc_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-dateformatter-hot_quiet.m"
check_pair oc-json-hot \
  "$ROOT/objcperf-lint/fixtures/bad/oc-json-hot_json_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-json-hot_value_varies.m"
check_pair oc-regex-hot \
  "$ROOT/objcperf-lint/fixtures/bad/oc-regex-hot_regex_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-regex-hot_pattern_varies.m"
check_pair oc-file-read-hot \
  "$ROOT/objcperf-lint/fixtures/bad/oc-file-read-hot_read_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-file-read-hot_quiet.m"
check_pair oc-clock-hot \
  "$ROOT/objcperf-lint/fixtures/bad/oc-clock-hot_clock_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-clock-hot_quiet.m"
check_pair oc-value-for-key-hot \
  "$ROOT/objcperf-lint/fixtures/bad/oc-value-for-key-hot_key_loop.m" \
  "$ROOT/objcperf-lint/fixtures/good/oc-value-for-key-hot_quiet.m"
echo "objcperf-lint smoke ok"
