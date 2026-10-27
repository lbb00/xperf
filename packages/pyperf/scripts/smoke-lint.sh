#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$ROOT/pyperf-lint${PYTHONPATH:+:$PYTHONPATH}"
BIN=(python3 -m pyperf_lint)
set +e
"${BIN[@]}" "$ROOT/pyperf-lint/fixtures/bad" \
  --severity pp-str-plus-hot=error --severity pp-list-plus-rebind=error --severity pp-print-hot=error
b=$?
"${BIN[@]}" "$ROOT/pyperf-lint/fixtures/good"
g=$?
"${BIN[@]}" "$ROOT/pyperf-lint/fixtures/bad/pp-list-plus-rebind_list_plus.py" --severity pp-list-plus-rebind=hint
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
out=$("${BIN[@]}" "$ROOT/pyperf-lint/fixtures/bad" --format json --no-fail)
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
check_pair pp-json-hot "$ROOT/pyperf-lint/fixtures/bad/pp-json-hot_json_loop.py" "$ROOT/pyperf-lint/fixtures/good/pp-json-hot_text_varies.py"
check_pair pp-deepcopy-hot "$ROOT/pyperf-lint/fixtures/bad/pp-deepcopy-hot_deepcopy_loop.py" "$ROOT/pyperf-lint/fixtures/good/pp-deepcopy-hot_share.py"
check_pair pp-open-hot "$ROOT/pyperf-lint/fixtures/bad/pp-open-hot_open_loop.py" "$ROOT/pyperf-lint/fixtures/good/pp-open-hot_path_varies.py"
outside_bad_fire() {
  local rule="$1" badf="$2"
  set +e
  out=$("${BIN[@]}" "$badf" --severity "${rule}=error" --format text --no-fail)
  local ec=$?
  set -e
  echo "$out" | grep -q "$rule" || { echo "$rule should fire on $badf under --scope all"; exit 1; }
}
outside_bad_fire pp-print-hot "$ROOT/pyperf-lint/fixtures/bad/pp-print-hot_print_outside.py"
outside_bad_fire pp-json-hot "$ROOT/pyperf-lint/fixtures/bad/pp-json-hot_json_once.py"

scope_loop_clean() {
  local f="$1"
  set +e
  "${BIN[@]}" "$f" --scope loop --strict-hints
  local ec=$?
  set -e
  [[ "$ec" -eq 0 ]] || { echo "--scope loop should clean $f, got $ec"; exit 1; }
}
scope_loop_clean "$ROOT/pyperf-lint/fixtures/bad/pp-print-hot_print_outside.py"
scope_loop_clean "$ROOT/pyperf-lint/fixtures/bad/pp-json-hot_json_once.py"
echo "pyperf-lint smoke ok"
