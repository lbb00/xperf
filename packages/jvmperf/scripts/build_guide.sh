#!/usr/bin/env sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LANG="${1:-en}"
javac -d "$ROOT/scripts" "$ROOT/scripts/BuildGuide.java"
java -Dguide.root="$ROOT" -cp "$ROOT/scripts" BuildGuide "$LANG"
