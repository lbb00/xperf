#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE_BIN="${NODE_BIN:-node}"
RESEARCH="${JSPERF_BENCH_OUT:-$ROOT/examples/bench/out}"
mkdir -p "$RESEARCH"
CORR="$ROOT/examples/bench/static_vs_v8_correlate.js"
JSON="$RESEARCH/static-vs-v8.json"
JSONL="$RESEARCH/results.jsonl"
export RESULTS_JSONL="$JSONL"
export CORR_JSON="$JSON"

echo "=== timings ==="
"$NODE_BIN" "$CORR" | tee "$RESEARCH/static-vs-v8-timing.txt"

# Per-case mini probes for --trace-deopt bailout counts (shape + delete focused)
count_bailouts() {
  local label="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  set +e
  "$NODE_BIN" --trace-deopt "$@" >"$tmp.out" 2>"$tmp.err"
  set -e
  cat "$tmp.out" "$tmp.err" >"$tmp.all"
  local n
  n=$(rg -c '\[bailout' "$tmp.all" 2>/dev/null || echo 0)
  echo "$label bailout_lines=$n"
  rg '\[bailout' "$tmp.all" 2>/dev/null | head -3 || true
  rm -f "$tmp" "$tmp.out" "$tmp.err" "$tmp.all"
}

echo "=== deopt spot checks ===" | tee "$RESEARCH/static-vs-v8-deopt.txt"
{
  count_bailouts "case1_mono" -e '
    const N=2e5; function m(x,y){return {x,y,z:0}}; function h(o){return o.x+o.y+o.z};
    let s=0; for(let i=0;i<N;i++) s=(s+h(m(i&1023,(i+1)&1023)))|0; console.log(s);
  '
  count_bailouts "case1_poly" -e '
    const N=2e5;
    function p(f,x,y){const o={}; if(f){o.x=x;o.y=y}else{o.y=y;o.x=x} o.z=0; return o}
    function h(o){return o.x+o.y+o.z};
    let s=0; for(let i=0;i<N;i++) s=(s+h(p(i&1,i&1023,(i+1)&1023)))|0; console.log(s);
  '
  count_bailouts "case1_mono_then_poly" "$ROOT/examples/bench/deopt_probe.js"
  count_bailouts "case2_packed" -e '
    const N=2e5; const a=new Array(N); for(let i=0;i<N;i++) a[i]=i&1023;
    let s=0; for(let i=0;i<N;i++) s=(s+a[i])|0; console.log(s);
  '
  count_bailouts "case2_holey" -e '
    const N=2e5; const a=new Array(N); for(let i=0;i<N;i++) a[i]=i&1023;
    for(let i=0;i<N;i+=2) delete a[i];
    let s=0; for(let i=0;i<N;i++){const v=a[i]; if(v!==undefined) s=(s+v)|0} console.log(s);
  '
  count_bailouts "case4_tombstone" -e '
    const N=2e5; let s=0; for(let i=0;i<N;i++){const o={k:i&1023,keep:1}; o.k=undefined; s=(s+o.keep)|0}
    console.log(s);
  '
  count_bailouts "case4_delete" -e '
    const N=2e5; let s=0; for(let i=0;i<N;i++){const o={k:i&1023,keep:1}; delete o.k; s=(s+o.keep)|0}
    console.log(s);
  '
  count_bailouts "case5_new_once" -e '
    const N=2e5; const buf=new Uint8Array(16); let s=0;
    for(let i=0;i<N;i++){buf[0]=i&255; s=(s+buf[0])|0} console.log(s);
  '
  count_bailouts "case5_new_in_loop" -e '
    const N=2e5; let s=0;
    for(let i=0;i<N;i++){const buf=new Uint8Array(16); buf[0]=i&255; s=(s+buf[0])|0}
    console.log(s);
  '
} | tee -a "$RESEARCH/static-vs-v8-deopt.txt"

echo "JSON -> $JSON"
