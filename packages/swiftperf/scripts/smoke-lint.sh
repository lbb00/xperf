#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINT=()
check_one() {
  local rule="$1" badf="$2" goodf="$3"
  set +e
  "${LINT[@]}" "$badf" --severity "${rule}=error" >/dev/null
  local be=$?
  "${LINT[@]}" "$goodf" --strict-hints >/dev/null
  local ge=$?
  local out
  out=$("${LINT[@]}" "$badf" \
    --severity sp-print-hot=error \
    --severity sp-array-no-reserve=error \
    --severity sp-dateformatter-hot=error \
    --severity sp-json-decode-hot=error \
    --severity sp-regex-hot=error --severity sp-file-read-hot=error --severity sp-clock-hot=error --severity sp-value-for-key-hot=error \
    2>/dev/null)
  local ae=$?
  set -e
  [[ "$be" -eq 1 ]] || { echo "$rule bad should exit 1, got $be"; exit 1; }
  [[ "$ge" -eq 0 ]] || { echo "$rule good should exit 0, got $ge"; exit 1; }
  [[ "$ae" -eq 1 ]] || { echo "$rule bad (all error) should exit 1, got $ae"; exit 1; }
  echo "$out" | grep -q "$rule" || { echo "$rule bad did not report $rule"; exit 1; }
  local other
  other=$(echo "$out" | grep -oE 'sp-[a-z0-9-]+' | grep -v -x "$rule" || true)
  if [[ -n "${other}" ]]; then
    echo "$rule bad fired another rule:"
    echo "$other"
    exit 1
  fi
}
run_fixtures() {
  LINT=("$@")
  set +e
  "${LINT[@]}" "$ROOT/swiftperf-lint/fixtures/bad" \
    --severity sp-print-hot=error \
    --severity sp-array-no-reserve=error \
    --severity sp-dateformatter-hot=error --severity sp-json-decode-hot=error --severity sp-regex-hot=error --severity sp-file-read-hot=error --severity sp-clock-hot=error --severity sp-value-for-key-hot=error
  b=$?
  "${LINT[@]}" "$ROOT/swiftperf-lint/fixtures/good" --strict-hints
  g=$?
  set -e
  [[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
  [[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
  "${LINT[@]}" "$ROOT/swiftperf-lint/fixtures/bad/sp-array-no-reserve_append_no_reserve.swift" --no-fail 2>&1 | grep -q sp-array-no-reserve \
    || { echo "sp-array-no-reserve fixture must fire"; exit 1; }
  check_one sp-dateformatter-hot \
    "$ROOT/swiftperf-lint/fixtures/bad/sp-dateformatter-hot_formatter_loop.swift" \
    "$ROOT/swiftperf-lint/fixtures/good/sp-dateformatter-hot_quiet.swift"
  check_one sp-json-decode-hot \
    "$ROOT/swiftperf-lint/fixtures/bad/sp-json-decode-hot_decode_loop.swift" \
    "$ROOT/swiftperf-lint/fixtures/good/sp-json-decode-hot_quiet.swift"
  check_one sp-file-read-hot \
    "$ROOT/swiftperf-lint/fixtures/bad/sp-file-read-hot_read_loop.swift" \
    "$ROOT/swiftperf-lint/fixtures/good/sp-file-read-hot_path_varies.swift"
  check_one sp-clock-hot \
    "$ROOT/swiftperf-lint/fixtures/bad/sp-clock-hot_clock_loop.swift" \
    "$ROOT/swiftperf-lint/fixtures/good/sp-clock-hot_await_loop.swift"
  check_one sp-value-for-key-hot \
    "$ROOT/swiftperf-lint/fixtures/bad/sp-value-for-key-hot_key_loop.swift" \
    "$ROOT/swiftperf-lint/fixtures/good/sp-value-for-key-hot_quiet.swift"
  check_one sp-regex-hot \
    "$ROOT/swiftperf-lint/fixtures/bad/sp-regex-hot_regex_loop.swift" \
    "$ROOT/swiftperf-lint/fixtures/good/sp-regex-hot_pattern_varies.swift"
}
if command -v swift >/dev/null 2>&1; then
  cd "$ROOT/swiftperf-lint"
  swift build -c release
  BIN=$(swift build -c release --show-bin-path)/swiftperf-lint
  run_fixtures "$BIN"
  echo "swiftperf-lint smoke ok (SPM)"
else
  echo "swiftperf-lint: no swift toolchain; G0 via scripts/text-lint.cjs (heuristic parity with main.swift)"
  run_fixtures node "$ROOT/scripts/text-lint.cjs"
  echo "swiftperf-lint smoke ok (text fallback)"
fi
