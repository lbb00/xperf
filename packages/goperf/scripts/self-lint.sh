#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/goperf-lint/goperf-lint"
(cd "$ROOT/goperf-lint" && go build -o goperf-lint ./cmd/goperf-lint)
"$BIN" "$ROOT/goperf-lint/cmd" "$ROOT/goperf-lint/internal" --scope loop --strict-hints
echo "goperf-lint self-lint ok"
