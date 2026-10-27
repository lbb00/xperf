#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
php "$ROOT/phpperf-lint/phpperf-lint.php" "$ROOT/phpperf-lint/phpperf-lint.php" --scope loop --strict-hints
echo "phpperf-lint self-lint ok"
