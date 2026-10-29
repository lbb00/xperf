#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if command -v swift >/dev/null 2>&1; then
  cd "$ROOT/swiftperf-lint"
  swift build -c release
  BIN=$(swift build -c release --show-bin-path)/swiftperf-lint
  "$BIN" "$ROOT/swiftperf-lint/Sources" "$ROOT/examples" --scope loop --strict-hints
  echo "swiftperf-lint self-lint ok (SPM)"
else
  node "$ROOT/scripts/text-lint.cjs" "$ROOT/swiftperf-lint/Sources" "$ROOT/examples" --scope loop --strict-hints
  echo "swiftperf-lint self-lint ok (text fallback)"
fi
