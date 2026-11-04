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

# Static export keeps root <html lang="en">. Crawlers do not run the client
# HtmlLang effect, so rewrite zh HTML to zh-CN for SEO/GEO.
python3 - <<"PY"
from pathlib import Path
root = Path("out") / "zh"
if root.is_dir():
    n = 0
    for html in root.rglob("*.html"):
        text = html.read_text(encoding="utf-8")
        new = text.replace("<html lang=\"en\"", "<html lang=\"zh-CN\"", 1)
        if new != text:
            html.write_text(new, encoding="utf-8")
            n += 1
    print(f"build-pages: set html lang=zh-CN on {n} files under out/zh/")
PY
