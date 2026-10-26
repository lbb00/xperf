"use strict";
/**
 * Packed Smi fill+sum vs holey (delete / skipped index) fill+sum.
 * Construction differs by design; report construct+iterate wall time and note workload shape.
 */
const fs = require("fs");

const N = 2e5;
const ROUNDS = 9;
const WARM = 3;

function packedFillSum() {
  const a = new Array(N);
  for (let i = 0; i < N; i++) a[i] = i;
  let s = 0;
  for (let i = 0; i < N; i++) s += a[i];
  return s;
}

function holeyDeleteFillSum() {
  const a = new Array(N);
  for (let i = 0; i < N; i++) a[i] = i;
  for (let i = 0; i < N; i += 2) delete a[i];
  let s = 0;
  for (let i = 0; i < N; i++) {
    const v = a[i];
    if (v !== undefined) s += v;
  }
  return s;
}

function holeySkipFillSum() {
  const a = new Array(N);
  for (let i = 0; i < N; i += 2) a[i] = i;
  let s = 0;
  for (let i = 0; i < N; i++) {
    const v = a[i];
    if (v !== undefined) s += v;
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

const packedMs = timeMany(packedFillSum);
const delMs = timeMany(holeyDeleteFillSum);
const skipMs = timeMany(holeySkipFillSum);
const packedMed = median(packedMs);
const delMed = median(delMs);
const skipMed = median(skipMs);

console.log("bench=elements_packed_vs_holey");
console.log("node=%s v8=%s", process.version, process.versions.v8);
console.log("N=%d rounds=%d warm=%d", N, ROUNDS, WARM);
console.log("packed_median_ms=%s packed_ops_per_s=%s", fmt(packedMed, 3), fmt(N / (packedMed / 1000), 0));
console.log("holey_delete_median_ms=%s holey_delete_ops_per_s=%s", fmt(delMed, 3), fmt(N / (delMed / 1000), 0));
console.log("holey_skip_median_ms=%s holey_skip_ops_per_s=%s", fmt(skipMed, 3), fmt(N / (skipMed / 1000), 0));
console.log("note=holey_skip writes half the slots; compare kind behavior, not raw speed alone");

const out = process.env.RESULTS_JSONL;
if (out) {
  const line = JSON.stringify({
    bench: "elements_packed_vs_holey",
    node: process.version,
    v8: process.versions.v8,
    arch: process.arch,
    platform: process.platform,
    N,
    rounds: ROUNDS,
    warm: WARM,
    packed_median_ms: packedMed,
    holey_delete_median_ms: delMed,
    holey_skip_median_ms: skipMed,
    packed_ops_per_s: N / (packedMed / 1000),
    holey_delete_ops_per_s: N / (delMed / 1000),
    holey_skip_ops_per_s: N / (skipMed / 1000),
    note: "holey_skip writes half the slots",
    ts: new Date().toISOString(),
  });
  fs.appendFileSync(out, line + "\n");
}
