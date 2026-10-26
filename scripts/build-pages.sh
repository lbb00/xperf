#!/usr/bin/env bash
# Build or preview the documentation site. See docs/release.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/site-app"
if [[ ! -d node_modules ]]; then
  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install
  fi
fi
node assemble.js
if [[ "${1:-build}" == "serve" ]]; then
  exec npm run dev -- --port 3000
fi
export PAGES_STATIC="${PAGES_STATIC:-1}"
npm run build
