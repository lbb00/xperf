"use strict";
/**
 * Dense number[] sum vs Float64Array sum (numeric hot loop).
 * Reports honest medians; typed arrays are not always faster on packed doubles.
 */
const fs = require("fs");

const N = 1e6;
const ROUNDS = 9;
const WARM = 3;

function sumNumberArray() {
  const a = new Array(N);
  for (let i = 0; i < N; i++) a[i] = i * 0.5 + 0.25;
  let s = 0;
  for (let i = 0; i < N; i++) s += a[i];
  return s;
}

function sumFloat64() {
  const a = new Float64Array(N);
  for (let i = 0; i < N; i++) a[i] = i * 0.5 + 0.25;
  let s = 0;
  for (let i = 0; i < N; i++) s += a[i];
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

const numMs = timeMany(sumNumberArray);
const f64Ms = timeMany(sumFloat64);
const numMed = median(numMs);
const f64Med = median(f64Ms);

console.log("bench=typed_array_vs_number_array");
console.log("node=%s v8=%s", process.version, process.versions.v8);
console.log("N=%d rounds=%d warm=%d", N, ROUNDS, WARM);
console.log("number_array_median_ms=%s number_array_ops_per_s=%s", fmt(numMed, 3), fmt(N / (numMed / 1000), 0));
console.log("float64_median_ms=%s float64_ops_per_s=%s", fmt(f64Med, 3), fmt(N / (f64Med / 1000), 0));
console.log("ratio_number_over_float64=%s", fmt(numMed / f64Med, 3));

const out = process.env.RESULTS_JSONL;
if (out) {
  const line = JSON.stringify({
    bench: "typed_array_vs_number_array",
    node: process.version,
    v8: process.versions.v8,
    arch: process.arch,
    platform: process.platform,
    N,
    rounds: ROUNDS,
    warm: WARM,
    number_array_median_ms: numMed,
    float64_median_ms: f64Med,
    number_array_ops_per_s: N / (numMed / 1000),
    float64_ops_per_s: N / (f64Med / 1000),
    ts: new Date().toISOString(),
  });
  fs.appendFileSync(out, line + "\n");
}
