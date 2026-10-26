#!/usr/bin/env bash
# Download optional JMH/JOL/etc. jars into packages/jvmperf/lib (gitignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="${JVMPERF_LIB_DIR:-$ROOT/lib}"
mkdir -p "$LIB"
BASE="${MAVEN_CENTRAL:-https://repo1.maven.org/maven2}"

fetch() {
  local rel="$1"
  local out="$2"
  if [[ -f "$LIB/$out" ]]; then
    echo "have $out"
    return
  fi
  echo "fetch $out"
  curl -fsSL -o "$LIB/$out" "$BASE/$rel"
}

fetch "org/openjdk/jmh/jmh-core/1.37/jmh-core-1.37.jar" "jmh-core-1.37.jar"
fetch "org/openjdk/jmh/jmh-generator-annprocess/1.37/jmh-generator-annprocess-1.37.jar" "jmh-generator-annprocess-1.37.jar"
fetch "net/sf/jopt-simple/jopt-simple/5.0.4/jopt-simple-5.0.4.jar" "jopt-simple-5.0.4.jar"
fetch "org/apache/commons/commons-math3/3.6.1/commons-math3-3.6.1.jar" "commons-math3-3.6.1.jar"
fetch "org/openjdk/jol/jol-core/0.17/jol-core-0.17.jar" "jol-core-0.17.jar"
fetch "it/unimi/dsi/fastutil-core/8.5.19/fastutil-core-8.5.19.jar" "fastutil-core-8.5.19.jar"
fetch "org/eclipse/collections/eclipse-collections/13.0.0/eclipse-collections-13.0.0.jar" "eclipse-collections-13.0.0.jar"
fetch "org/eclipse/collections/eclipse-collections-api/13.0.0/eclipse-collections-api-13.0.0.jar" "eclipse-collections-api-13.0.0.jar"
fetch "org/jetbrains/kotlinx/kotlinx-coroutines-core-jvm/1.11.0/kotlinx-coroutines-core-jvm-1.11.0.jar" "kotlinx-coroutines-core-jvm-1.11.0.jar"
fetch "androidx/collection/collection-jvm/1.7.0/collection-jvm-1.7.0.jar" "collection-jvm-1.7.0.jar"
fetch "androidx/annotation/annotation-jvm/1.9.1/annotation-jvm-1.9.1.jar" "annotation-jvm-1.9.1.jar"
fetch "org/jspecify/jspecify/1.0.0/jspecify-1.0.0.jar" "jspecify-1.0.0.jar"

echo "OK → $LIB ($(ls -1 "$LIB"/*.jar 2>/dev/null | wc -l) jars)"
