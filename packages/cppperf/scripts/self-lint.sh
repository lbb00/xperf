#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/cppperf-lint"
make -s
./cppperf-lint src --strict-hints
echo "cppperf-lint self-lint ok"
