#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
php "$ROOT/phpperf-lint/phpperf-lint.php" "$ROOT/phpperf-lint/phpperf-lint.php" --strict-hints
echo "phpperf-lint self-lint ok"
