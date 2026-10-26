#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$ROOT/pyperf-lint${PYTHONPATH:+:$PYTHONPATH}"
BIN=(python3 -m pyperf_lint)
set +e
"${BIN[@]}" "$ROOT/pyperf-lint/fixtures/bad" \
  --severity pp-str-plus-in-loop=error --severity pp-list-plus-rebind=error --severity pp-print-in-loop=error
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
check_pair pp-json-in-loop "$ROOT/pyperf-lint/fixtures/bad/pp-json-in-loop_json_loop.py" "$ROOT/pyperf-lint/fixtures/good/pp-json-in-loop_json_once.py"
check_pair pp-deepcopy-in-loop "$ROOT/pyperf-lint/fixtures/bad/pp-deepcopy-in-loop_deepcopy_loop.py" "$ROOT/pyperf-lint/fixtures/good/pp-deepcopy-in-loop_deepcopy_once.py"
check_pair pp-open-in-loop "$ROOT/pyperf-lint/fixtures/bad/pp-open-in-loop_open_loop.py" "$ROOT/pyperf-lint/fixtures/good/pp-open-in-loop_open_once.py"
echo "pyperf-lint smoke ok"
