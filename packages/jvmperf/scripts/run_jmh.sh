#!/usr/bin/env sh
# Compile and run JMH benches under jmh-benches/; emit JMH JSON then convert to research JSONL.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="${JVMPERF_LIB_DIR:-$ROOT/lib}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
export JAVA_HOME
PATH="$JAVA_HOME/bin:$PATH"
export PATH

CP="$LIB/jmh-core-1.37.jar:$LIB/jopt-simple-5.0.4.jar:$LIB/commons-math3-3.6.1.jar"
PP="$LIB/jmh-generator-annprocess-1.37.jar:$CP"
SRC="$ROOT/jmh-benches/src"
OUT="$ROOT/jmh-benches/build/classes"
GEN="$ROOT/jmh-benches/build/generated"
RES_DIR="${JMH_RESULTS_DIR:-$ROOT/research/bench-results}"
FILTER="${1:-.}"

mkdir -p "$OUT" "$GEN" "$RES_DIR"

# Contended (J22) needs the internal annotation package at compile time.
EXPORTS="--add-exports=java.base/jdk.internal.vm.annotation=ALL-UNNAMED"
# Vector API (J28) is an incubator module when that bench is present.
MODULES=""
if [ -f "$SRC/jmhperf/bench/J28_VectorVsScalar.java" ]; then
  MODULES="--add-modules=jdk.incubator.vector"
fi

echo "== javac (JMH annprocess) =="
find "$OUT" -type f -name '*.class' -delete 2>/dev/null || true
rm -rf "$GEN"/* "$OUT"/*
javac -source 25 -target 25 \
  $EXPORTS $MODULES \
  -cp "$CP" \
  -processorpath "$PP" \
  -d "$OUT" \
  -s "$GEN" \
  "$SRC"/jmhperf/bench/*.java

# Compile any generated sources (BenchmarkList is written to -d)
if [ -n "$(find "$GEN" -name '*.java' 2>/dev/null)" ]; then
  javac -source 25 -target 25 $EXPORTS $MODULES -cp "$CP:$OUT" -d "$OUT" $(find "$GEN" -name '*.java')
fi

# Ensure BenchmarkList exists
if [ ! -f "$OUT/META-INF/BenchmarkList" ]; then
  echo "ERROR: META-INF/BenchmarkList missing after annotation processing" >&2
  find "$OUT" -type f | head -40 >&2
  exit 1
fi

# Compile JsonlConvert helper if present
if [ -f "$ROOT/scripts/JmhJsonToJsonl.java" ]; then
  javac -source 25 -target 25 -d "$ROOT/scripts" "$ROOT/scripts/JmhJsonToJsonl.java"
fi

run_one() {
  name="$1"
  json="$RES_DIR/${name}.jmh.json"
  jsonl="$RES_DIR/${name}.jsonl"
  echo "== JMH $name =="
  extra=""
  case "$name" in
    J28*) extra="--add-modules=jdk.incubator.vector" ;;
  esac
  java $extra -cp "$OUT:$CP" org.openjdk.jmh.Main \
    "$name" \
    -foe true \
    -v NORMAL \
    -rf json -rff "$json" \
    -prof gc \
    ${JMH_EXTRA_ARGS:-}
  java -cp "$ROOT/scripts" JmhJsonToJsonl "$json" "$jsonl"
  echo "wrote $jsonl"
}

case "$FILTER" in
  J20*|box*|Box*) run_one J20_BoxingSum ;;
  J21*|soa*|SoA*) run_one J21_SoABandwidth ;;
  J22*|false*|False*) run_one J22_FalseSharing ;;
  J23*|string*|String*) run_one J23_StringConcat ;;
  J24*|pool*|Pool*) run_one J24_PoolVsAlloc ;;
  J25*|presize*|Presize*) run_one J25_Presize ;;
  J26*|regex*|Regex*) run_one J26_RegexCompile ;;
  J27*|format*|Format*) run_one J27_FormatHot ;;
  J28*|vector*|Vector*) run_one J28_VectorVsScalar ;;
  J29*|vt*|VT*|virtual*|Virtual*) run_one J29_VirtualThreadsIo ;;
  J30*|buf*|Buf*|io*|Io*) run_one J30_BufferedIo ;;
  J31*|jol*|Jol*|maps*|Maps*)
    exec "$ROOT/scripts/run_jol_maps.sh"
    ;;
  J32*|evidence*|Evidence*|batch*|Batch*) run_one J32_RuleEvidenceBatch ;;
  K13*) exec "$ROOT/scripts/run_kotlin_alloc.sh" K13 ;;
  K14*) exec "$ROOT/scripts/run_kotlin_alloc.sh" K14 ;;
  phase4)
    "$ROOT/scripts/run_jol_maps.sh"
    "$ROOT/scripts/run_kotlin_alloc.sh" phase4
    ;;
  phase2)
    run_one J22_FalseSharing
    run_one J24_PoolVsAlloc
    run_one J30_BufferedIo
    ;;
  phase3)
    run_one J20_BoxingSum
    run_one J26_RegexCompile
    run_one J27_FormatHot
    ;;
  phase3stretch|stretch)
    run_one J28_VectorVsScalar
    run_one J29_VirtualThreadsIo
    ;;
  all|.)
    run_one J20_BoxingSum
    run_one J21_SoABandwidth
    run_one J22_FalseSharing
    run_one J23_StringConcat
    run_one J24_PoolVsAlloc
    run_one J25_Presize
    run_one J26_RegexCompile
    run_one J27_FormatHot
    run_one J28_VectorVsScalar
    run_one J29_VirtualThreadsIo
    run_one J30_BufferedIo
    "$ROOT/scripts/run_jol_maps.sh"
    "$ROOT/scripts/run_kotlin_alloc.sh" phase4
    ;;
  *)
    run_one "$FILTER"
    ;;
esac
