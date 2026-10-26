#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ruby "$ROOT/rubyperf-lint/rubyperf-lint.rb" "$ROOT/rubyperf-lint/rubyperf-lint.rb" --strict-hints
echo "rubyperf-lint self-lint ok"
