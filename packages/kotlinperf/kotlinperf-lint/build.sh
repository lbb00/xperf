#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
if ! command -v kotlinc >/dev/null 2>&1; then
  echo "kotlinc not found" >&2
  exit 2
fi
mkdir -p out
# Fat jar with runtime so `java -jar` works without kotlin CLI
kotlinc -include-runtime -d out/kotlinperf-lint.jar src/Main.kt src/Scan.kt
# Manifest main class — kotlinc -include-runtime doesn't always set it for multi-file;
# use kotlin CLI if present, else java with MainKt
if command -v kotlin >/dev/null 2>&1; then
  cat > kotlinperf-lint << 'LAUNCH'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec kotlin -cp "$DIR/out/kotlinperf-lint.jar" com.kotlinperf.lint.MainKt "$@"
LAUNCH
else
  # Extract and run via java - need kotlin stdlib on cp; -include-runtime embeds it
  cat > kotlinperf-lint << 'LAUNCH'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec java -cp "$DIR/out/kotlinperf-lint.jar" com.kotlinperf.lint.MainKt "$@"
LAUNCH
fi
chmod +x kotlinperf-lint
echo "built $ROOT/kotlinperf-lint"
