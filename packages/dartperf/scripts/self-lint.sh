#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "${HOME}/dart-sdk/bin/dart" ]]; then
  export PATH="${HOME}/dart-sdk/bin:${PATH}"
fi
if ! command -v dart >/dev/null 2>&1; then
  echo "dartperf-lint self-lint SKIP (no dart SDK)"
  exit 0
fi
cd "$ROOT/dartperf-lint"
dart pub get
dart run bin/dartperf_lint.dart ../examples --strict-hints
echo "dartperf-lint self-lint ok"
