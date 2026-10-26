"use strict";
/**
 * Same field-order constructors (mono-friendly) vs divergent addition order (poly-ish).
 * Plain Node; prints version + median timings; appends one JSONL line when RESULTS_JSONL is set.
 */
const fs = require("fs");

const N = 2e5;
const ROUNDS = 9;
const WARM = 3;

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

function runMono() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    const o = makeMono(i, i + 1);
    s += o.x + o.y + o.z;
  }
  return s;
}

function runPoly() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    const o = makePoly(i & 1, i, i + 1);
    s += o.x + o.y + o.z;
  }
  return s;
}

function median(xs) {
  const a = xs.slice().sort((p, q) => p - q);
  const m = Math.floor(a.length / 2);
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
}

function timeMany(fn) {
  for (let i = 0; i < WARM; i++) fn();
  const samples = [];
  let sink = 0;
  for (let r = 0; r < ROUNDS; r++) {
    const t0 = process.hrtime.bigint();
    sink += fn();
    const t1 = process.hrtime.bigint();
    samples.push(Number(t1 - t0) / 1e6);
  }
  if (sink === Infinity) process.exit(2);
  return samples;
}

function fmt(n, d) {
  return Number(n).toFixed(d);
}

const monoMs = timeMany(runMono);
const polyMs = timeMany(runPoly);
const monoMed = median(monoMs);
const polyMed = median(polyMs);
const monoOps = N / (monoMed / 1000);
const polyOps = N / (polyMed / 1000);

console.log("bench=shape_mono_vs_poly");
console.log("node=%s v8=%s", process.version, process.versions.v8);
console.log("N=%d rounds=%d warm=%d", N, ROUNDS, WARM);
console.log("mono_median_ms=%s mono_ops_per_s=%s", fmt(monoMed, 3), fmt(monoOps, 0));
console.log("poly_median_ms=%s poly_ops_per_s=%s", fmt(polyMed, 3), fmt(polyOps, 0));
console.log("ratio_poly_over_mono=%s", fmt(polyMed / monoMed, 3));

const out = process.env.RESULTS_JSONL;
if (out) {
  const line = JSON.stringify({
    bench: "shape_mono_vs_poly",
    node: process.version,
    v8: process.versions.v8,
    arch: process.arch,
    platform: process.platform,
    N,
    rounds: ROUNDS,
    warm: WARM,
    mono_median_ms: monoMed,
    poly_median_ms: polyMed,
    mono_ops_per_s: monoOps,
    poly_ops_per_s: polyOps,
    ts: new Date().toISOString(),
  });
  fs.appendFileSync(out, line + "\n");
}
