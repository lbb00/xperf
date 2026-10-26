# Optional locations for the external libraries used by selected examples.
# Set JVMPERF_LIB_DIR to a directory containing the jars listed in README.md.
# When unset, defaults to <repo>/lib if that directory exists.

if [ -n "${JAVA_HOME:-}" ]; then
  PATH="$JAVA_HOME/bin:$PATH"
  export PATH
fi

_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0" 2>/dev/null || dirname -- "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
if [ -z "${JVMPERF_LIB_DIR:-}" ] && [ -n "${_SCRIPT_DIR:-}" ] && [ -d "$_SCRIPT_DIR/../lib" ]; then
  JVMPERF_LIB_DIR="$_SCRIPT_DIR/../lib"
fi
JVMPERF_LIB_DIR=${JVMPERF_LIB_DIR:-}

if [ -n "$JVMPERF_LIB_DIR" ]; then
  JMH_CP=${JMH_CP:-$JVMPERF_LIB_DIR/jmh-core-1.37.jar:$JVMPERF_LIB_DIR/jmh-generator-annprocess-1.37.jar:$JVMPERF_LIB_DIR/jopt-simple-5.0.4.jar:$JVMPERF_LIB_DIR/commons-math3-3.6.1.jar}
  PRIM_CP=${PRIM_CP:-$JVMPERF_LIB_DIR/fastutil-core-8.5.19.jar:$JVMPERF_LIB_DIR/eclipse-collections-13.0.0.jar:$JVMPERF_LIB_DIR/eclipse-collections-api-13.0.0.jar}
  JOL_CP=${JOL_CP:-$JVMPERF_LIB_DIR/jol-core-0.17.jar}
  KX_CP=${KX_CP:-$JVMPERF_LIB_DIR/kotlinx-coroutines-core-jvm-1.11.0.jar:$JVMPERF_LIB_DIR/collection-jvm-1.7.0.jar:$JVMPERF_LIB_DIR/annotation-jvm-1.9.1.jar:$JVMPERF_LIB_DIR/jspecify-1.0.0.jar}
else
  JMH_CP=${JMH_CP:-}
  PRIM_CP=${PRIM_CP:-}
  JOL_CP=${JOL_CP:-}
  KX_CP=${KX_CP:-}
fi

if [ -z "${ANDROID_JAR:-}" ] && [ -n "${ANDROID_HOME:-}" ]; then
  ANDROID_JAR="$ANDROID_HOME/platforms/android-34/android.jar"
fi

if [ -z "${KOTLIN_STDLIB:-}" ] && command -v kotlinc >/dev/null 2>&1; then
  KOTLINC_BIN=$(command -v kotlinc)
  KOTLINC_REAL=$(readlink -f "$KOTLINC_BIN" 2>/dev/null || echo "$KOTLINC_BIN")
  KOTLIN_STDLIB="$(dirname "$KOTLINC_REAL")/../lib/kotlin-stdlib.jar"
fi

export JVMPERF_LIB_DIR JMH_CP PRIM_CP JOL_CP KX_CP ANDROID_JAR KOTLIN_STDLIB
