#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/jsperf-lint/bin/jsperf-lint.js"
set +e
node "$BIN" "$ROOT/jsperf-lint/fixtures/bad" --format text
b=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/good" --format text
g=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/bad/jp-alloc-in-loop_new_in_loop.js" --preset app
a1=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/bad/jp-alloc-in-loop_new_in_loop.js" --preset all
A1=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/bad/jp-delete-shape_delete.js" --preset app
a3=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/bad/jp-delete-shape_delete.js" --severity jp-delete-shape=error
a3e=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/bad/jp-console-in-loop_console_loop.js" --preset app
a2=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/bad/jp-alloc-in-loop_new_in_loop.js" --preset app --strict-hints
s1=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/bad/jp-map-filter-chain_map_filter_chain.js" --preset app
a6=$?
set -e
[[ "$b" -eq 1 ]] || { echo "expected bad fixtures exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "expected good fixtures exit 0, got $g"; exit 1; }
[[ "$a1" -eq 0 ]] || { echo "app jp-alloc-in-loop-only should exit 0 (off), got $a1"; exit 1; }
[[ "$A1" -eq 1 ]] || { echo "all jp-alloc-in-loop-only should exit 1, got $A1"; exit 1; }
[[ "$a3" -eq 0 ]] || { echo "app jp-delete-shape is off; should exit 0, got $a3"; exit 1; }
[[ "$a3e" -eq 1 ]] || { echo "jp-delete-shape=error should exit 1, got $a3e"; exit 1; }
[[ "$a2" -eq 0 ]] || { echo "app jp-console-in-loop-only should exit 0 (off), got $a2"; exit 1; }
[[ "$s1" -eq 0 ]] || { echo "app jp-alloc-in-loop is off; strict-hints should exit 0, got $s1"; exit 1; }
[[ "$a6" -eq 0 ]] || { echo "app jp-map-filter-chain-only should exit 0 (hint), got $a6"; exit 1; }
# G3: delete map[key] is jp-delete-shape when enabled, never jp-delete-array-hole
map_out=$(node "$BIN" "$ROOT/jsperf-lint/fixtures/cases/delete_map_key.js" --format json --no-fail --severity jp-delete-shape=hint)
echo "$map_out" | grep -q '"jp-delete-shape"' || { echo "expected jp-delete-shape on delete map[key]"; exit 1; }
echo "$map_out" | grep -q '"jp-delete-array-hole"' && { echo "jp-delete-array-hole must not fire on delete map[key]"; exit 1; }
jp6=$(node "$BIN" "$ROOT/jsperf-lint/fixtures/bad/jp-map-filter-chain_map_filter_chain.js" --format text --no-fail)
echo "$jp6" | grep -q jp-map-filter-chain || { echo "jp-map-filter-chain fixture must fire"; exit 1; }
check_pair() {
  local rule="$1" badf="$2" goodf="$3"
  set +e
  node "$BIN" "$badf" --severity "${rule}=error"
  local be=$?
  node "$BIN" "$goodf" --strict-hints
  local ge=$?
  set -e
  [[ "$be" -eq 1 ]] || { echo "$rule bad should exit 1, got $be"; exit 1; }
  [[ "$ge" -eq 0 ]] || { echo "$rule good should exit 0, got $ge"; exit 1; }
}
check_pair jp-regex-ctor-in-loop "$ROOT/jsperf-lint/fixtures/bad/jp-regex-ctor-in-loop_ctor_loop.js" "$ROOT/jsperf-lint/fixtures/good/jp-regex-ctor-in-loop_ctor_once.js"
check_pair jp-json-in-loop "$ROOT/jsperf-lint/fixtures/bad/jp-json-in-loop_json_loop.js" "$ROOT/jsperf-lint/fixtures/good/jp-json-in-loop_json_once.js"
check_pair jp-dom-query-in-loop "$ROOT/jsperf-lint/fixtures/bad/jp-dom-query-in-loop_query_loop.js" "$ROOT/jsperf-lint/fixtures/good/jp-dom-query-in-loop_query_once.js"
check_pair jp-intl-datetimeformat-in-loop "$ROOT/jsperf-lint/fixtures/bad/jp-intl-datetimeformat-in-loop_format_loop.js" "$ROOT/jsperf-lint/fixtures/good/jp-intl-datetimeformat-in-loop_format_once.js"
check_pair jp-readfile-sync-in-loop "$ROOT/jsperf-lint/fixtures/bad/jp-readfile-sync-in-loop_read_loop.js" "$ROOT/jsperf-lint/fixtures/good/jp-readfile-sync-in-loop_read_once.js"
check_pair jp-clock-in-loop "$ROOT/jsperf-lint/fixtures/bad/jp-clock-in-loop_clock_loop.js" "$ROOT/jsperf-lint/fixtures/good/jp-clock-in-loop_clock_once.js"
check_pair jp-query-all-star "$ROOT/jsperf-lint/fixtures/bad/jp-query-all-star_star_query.js" "$ROOT/jsperf-lint/fixtures/good/jp-query-all-star_narrow.js"
check_pair jp-query-all-star "$ROOT/jsperf-lint/fixtures/bad/jp-query-all-star_in_template.js" "$ROOT/jsperf-lint/fixtures/good/jp-query-all-star_template_narrow.js"
check_pair jp-execjs-in-timer "$ROOT/jsperf-lint/fixtures/bad/jp-execjs-in-timer_interval.js" "$ROOT/jsperf-lint/fixtures/good/jp-execjs-in-timer_once.js"
check_pair jp-clone-per-event "$ROOT/jsperf-lint/fixtures/bad/jp-clone-per-event_structured.js" "$ROOT/jsperf-lint/fixtures/good/jp-clone-per-event_field.js"
check_pair jp-clone-per-event "$ROOT/jsperf-lint/fixtures/bad/jp-clone-per-event_json_roundtrip.js" "$ROOT/jsperf-lint/fixtures/good/jp-clone-per-event_unrelated.js"
# G3 reverse-opt: loop header / nested fn bodies must stay clean
set +e
node "$BIN" "$ROOT/jsperf-lint/fixtures/good/jp-dom-query-in-loop_for_of_header.js" --strict-hints
h1=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/good/jp-clock-in-loop_nested_fn_later.js" --strict-hints
h2=$?
node "$BIN" "$ROOT/jsperf-lint/fixtures/good/jp-clock-in-loop_arrow_nested.js" --strict-hints
h3=$?
set -e
[[ "$h1" -eq 0 ]] || { echo "for-of header query must stay clean, got $h1"; exit 1; }
[[ "$h2" -eq 0 ]] || { echo "nested fn Date.now must stay clean, got $h2"; exit 1; }
[[ "$h3" -eq 0 ]] || { echo "nested arrow performance.now must stay clean, got $h3"; exit 1; }
# Path skips: *.test.ts and e2e/ must not be walked when scanning a tree
SKIP_ROOT=$(mktemp -d)
mkdir -p "$SKIP_ROOT/e2e" "$SKIP_ROOT/playwright-report" "$SKIP_ROOT/src"
cat > "$SKIP_ROOT/src/ok_probe.js" <<'PROBE'
for (let i = 0; i < 3; i++) {
  Date.now();
}
PROBE
cat > "$SKIP_ROOT/e2e/should_skip.js" <<'PROBE'
for (let i = 0; i < 3; i++) {
  Date.now();
}
PROBE
cat > "$SKIP_ROOT/playwright-report/should_skip.js" <<'PROBE'
for (let i = 0; i < 3; i++) {
  Date.now();
}
PROBE
cat > "$SKIP_ROOT/src/thing.test.ts" <<'PROBE'
for (let i = 0; i < 3; i++) {
  Date.now();
}
PROBE
set +e
skip_out=$(node "$BIN" "$SKIP_ROOT" --format json --no-fail --severity jp-clock-in-loop=hint)
set -e
echo "$skip_out" | grep -q 'ok_probe' || { echo "expected finding in src/ok_probe.js"; rm -rf "$SKIP_ROOT"; exit 1; }
echo "$skip_out" | grep -q 'should_skip' && { echo "e2e/playwright-report must be skipped"; rm -rf "$SKIP_ROOT"; exit 1; }
echo "$skip_out" | grep -q 'thing.test' && { echo "*.test.ts must be skipped"; rm -rf "$SKIP_ROOT"; exit 1; }
rm -rf "$SKIP_ROOT"
echo "jsperf-lint smoke ok"
