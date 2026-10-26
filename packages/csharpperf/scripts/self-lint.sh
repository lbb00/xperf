#!/usr/bin/env bash
set -euo pipefail
# Official user-local install (dotnet-install.sh)
# Prefer a dotnet already on PATH. Fall back to the user-local install script layout.
if ! command -v dotnet >/dev/null 2>&1 && [[ -x "${HOME}/.dotnet/dotnet" ]]; then
  export PATH="${HOME}/.dotnet:${PATH}"
  export DOTNET_ROOT="${HOME}/.dotnet"
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v dotnet >/dev/null 2>&1; then
  echo "csharpperf-lint self-lint SKIP (no dotnet SDK)"
  exit 0
fi
cd "$ROOT/csharpperf-lint"
dotnet build -c Release -v q
dotnet run -c Release --no-build -- Program.cs --strict-hints
echo "csharpperf-lint self-lint ok"
