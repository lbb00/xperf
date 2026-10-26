#!/usr/bin/env bash
# Compile the Android example against the selected Android SDK platform.
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/env.sh"
: "${ANDROID_JAR:?Set ANDROID_JAR or ANDROID_HOME to compile Android examples}"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

javac --release 25 -nowarn -cp "$ANDROID_JAR" -d "$OUT" \
  "$SCRIPT_DIR/../examples/android/A01_AndroidCollections.java"
printf 'Android example compiled successfully.\n'
