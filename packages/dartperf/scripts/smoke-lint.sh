#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "${HOME}/dart-sdk/bin/dart" ]]; then
  export PATH="${HOME}/dart-sdk/bin:${PATH}"
fi
if ! command -v dart >/dev/null 2>&1; then
  echo "dartperf-lint smoke SKIP (no dart SDK); fixtures present"
  ls "$ROOT/dartperf-lint/fixtures/bad" "$ROOT/dartperf-lint/fixtures/good" >/dev/null
  exit 0
fi
cd "$ROOT/dartperf-lint"
dart pub get
set +e
dart run bin/dartperf_lint.dart fixtures/bad \
  --severity dt-list-add-empty=error --severity dt-string-plus-in-loop=error --severity dt-print-in-loop=error --severity dt-growable-add-empty=error
b=$?
dart run bin/dartperf_lint.dart fixtures/good
g=$?
dart run bin/dartperf_lint.dart fixtures/bad/dt-growable-add-empty_empty_add.dart
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
out=$(dart run bin/dartperf_lint.dart fixtures/bad --format json --no-fail)
echo "$out" | grep -q '"dt-growable-add-empty"' || { echo "default should report dt-growable-add-empty"; exit 1; }
echo "dartperf-lint smoke ok"
