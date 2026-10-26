"use strict";
/**
 * Runtime JIT / deopt probe — NOT a lint rule.
 *
 *   node --trace-deopt examples/bench/deopt_probe.js
 *
 * Optional (fragile across Node/V8 builds; off by default):
 *   node --allow-natives-syntax --trace-deopt examples/bench/deopt_probe.js
 *   USE_NATIVES=1 node --allow-natives-syntax --trace-deopt ...
 *
 * Static jsperf-lint cannot see IC state, deopts, or optimization tier.
 * JP00x = allocation/shape smells only. JIT verification = profile/trace/bench.
 */
const N = Number(process.env.DEOPT_N || 2e5);

function makeMono(x, y) {
  return { x: x, y: y, z: 0 };
}

function makePoly(flag, x, y) {
  const o = {};
  if (flag) {
    o.x = x;
    o.y = y;
  } else {
    o.y = y;
    o.x = x;
  }
  o.z = 0;
  return o;
}

/** Shared hot load — first warmed monomorphic, then hit with divergent maps. */
function hotLoad(o) {
  return o.x + o.y + o.z;
}

function phaseMono() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    s = (s + hotLoad(makeMono(i & 1023, (i + 1) & 1023))) | 0;
  }
  return s;
}

function phasePolySameFn() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    s = (s + hotLoad(makePoly(i & 1, i & 1023, (i + 1) & 1023))) | 0;
  }
  return s;
}

console.log("deopt_probe node=%s v8=%s N=%d", process.version, process.versions.v8, N);
console.log("phase1=mono warm on hotLoad; phase2=same hotLoad with divergent shapes");
console.log("expect=--trace-deopt may show bailout when maps diverge after optimize");

const t0 = process.hrtime.bigint();
const sm = phaseMono();
const t1 = process.hrtime.bigint();
const sp = phasePolySameFn();
const t2 = process.hrtime.bigint();

console.log("mono_ms=%s sink=%s", (Number(t1 - t0) / 1e6).toFixed(3), sm);
console.log("poly_ms=%s sink=%s", (Number(t2 - t1) / 1e6).toFixed(3), sp);
console.log(
  "note=JP00x cannot detect JIT outcomes; compare bailout lines for hotLoad / phase drivers"
);

if (process.env.USE_NATIVES === "1") {
  try {
    const Optimize = new Function("fn", "%OptimizeFunctionOnNextCall(fn)");
    const Status = new Function("fn", "return %GetOptimizationStatus(fn)");
    hotLoad(makeMono(1, 2));
    Optimize(hotLoad);
    hotLoad(makeMono(3, 4));
    console.log("natives_after_mono_opt_status=%s", Status(hotLoad));
    hotLoad(makePoly(0, 5, 6));
    hotLoad(makePoly(1, 7, 8));
    console.log("natives_after_poly_calls_status=%s", Status(hotLoad));
  } catch (e) {
    console.log(
      "natives_syntax=failed (%s) — rerun with --allow-natives-syntax or ignore",
      e.message.split("\n")[0]
    );
  }
} else {
  console.log("natives_syntax=skipped (set USE_NATIVES=1 and pass --allow-natives-syntax)");
}
