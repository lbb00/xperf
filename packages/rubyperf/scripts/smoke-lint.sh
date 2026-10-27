#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN=(ruby "$ROOT/rubyperf-lint/rubyperf-lint.rb")
set +e
"${BIN[@]}" "$ROOT/rubyperf-lint/fixtures/bad" \
  --severity rb-string-plus-hot=error --severity rb-array-plus-rebind=error --severity rb-puts-hot=error
b=$?
"${BIN[@]}" "$ROOT/rubyperf-lint/fixtures/good"
g=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
check_pair() {
  local rule="$1" badf="$2" goodf="$3"
  set +e
  "${BIN[@]}" "$badf" --severity "${rule}=error"
  local be=$?
  "${BIN[@]}" "$goodf" --strict-hints
  local ge=$?
  set -e
  [[ "$be" -eq 1 ]] || { echo "$rule bad should exit 1, got $be"; exit 1; }
  [[ "$ge" -eq 0 ]] || { echo "$rule good should exit 0, got $ge"; exit 1; }
}
check_pair rb-regexp-new-hot "$ROOT/rubyperf-lint/fixtures/bad/rb-regexp-new-hot_regexp_loop.rb" "$ROOT/rubyperf-lint/fixtures/good/rb-regexp-new-hot_pattern_varies.rb"
check_pair rb-json-hot "$ROOT/rubyperf-lint/fixtures/bad/rb-json-hot_json_loop.rb" "$ROOT/rubyperf-lint/fixtures/good/rb-json-hot_text_varies.rb"
check_pair rb-file-read-hot "$ROOT/rubyperf-lint/fixtures/bad/rb-file-read-hot_read_loop.rb" "$ROOT/rubyperf-lint/fixtures/good/rb-file-read-hot_path_varies.rb"
echo "rubyperf-lint smoke ok"
