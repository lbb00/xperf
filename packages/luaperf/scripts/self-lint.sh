#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
lua "$ROOT/luaperf-lint/luaperf-lint.lua" "$ROOT/examples" --scope loop --strict-hints
echo "luaperf-lint self-lint ok"
