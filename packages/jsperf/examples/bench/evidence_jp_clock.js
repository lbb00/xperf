"use strict";
/**
 * jp-clock-hot: Date.now / performance.now once outside the loop vs each pass.
 * Warm 3, median of 9. Prints every sample. Writes JSONL only when EVIDENCE_DIR is set.
 */
const fs = require("fs");
const path = require("path");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.CLOCK_N || 100000);
const OUT_DIR = process.env.EVIDENCE_DIR || "";

function median(xs) {
  const a = xs.slice().sort((p, q) => p - q);
  const m = Math.floor(a.length / 2);
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
}

function timeMany(name, fn) {
  for (let i = 0; i < WARM; i++) fn();
  const samples = [];
  let sink = 0;
  for (let r = 0; r < ROUNDS; r++) {
    const t0 = process.hrtime.bigint();
    sink = (sink + (fn() | 0)) | 0;
    const t1 = process.hrtime.bigint();
    samples.push(Number(t1 - t0) / 1e6);
  }
  if (sink === Infinity) process.exit(2);
  const med = median(samples);
  console.log(
    name +
      " median_ms=" +
      med.toFixed(3) +
      " samples " +
      samples.map((s) => s.toFixed(3)).join(" ")
  );
  return med;
}

function dateOnce() {
  const t = Date.now();
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + (t & 1)) | 0;
  return s;
}
function dateEach() {
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + (Date.now() & 1)) | 0;
  return s;
}
function perfOnce() {
  const t = performance.now();
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + (t & 1)) | 0;
  return s;
}
function perfEach() {
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + (performance.now() & 1)) | 0;
  return s;
}

const dateOnceMs = timeMany("date_now_once", dateOnce);
const dateEachMs = timeMany("date_now_each", dateEach);
const perfOnceMs = timeMany("perf_now_once", perfOnce);
const perfEachMs = timeMany("perf_now_each", perfEach);

const node = process.version;
const v8 = process.versions.v8;
const ts = new Date().toISOString();
const rows = [
  { rule: "jp-clock-hot", case: "date_now_once", role: "after", node, v8, median_ms: dateOnceMs, ops: N, ratio: 1, ts },
  { rule: "jp-clock-hot", case: "date_now_each", role: "before", node, v8, median_ms: dateEachMs, ops: N, ratio: dateEachMs / dateOnceMs, ts },
  { rule: "jp-clock-hot", case: "perf_now_once", role: "after", node, v8, median_ms: perfOnceMs, ops: N, ratio: 1, ts },
  { rule: "jp-clock-hot", case: "perf_now_each", role: "before", node, v8, median_ms: perfEachMs, ops: N, ratio: perfEachMs / perfOnceMs, ts },
];

if (OUT_DIR) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const p = path.join(OUT_DIR, "jp-clock-hot.jsonl");
  fs.writeFileSync(p, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log("wrote " + p);
}
console.log(
  "node=%s v8=%s date=%s perf=%s",
  node,
  v8,
  (dateEachMs / dateOnceMs).toFixed(3),
  (perfEachMs / perfOnceMs).toFixed(3)
);
console.log("DONE_NODE_CLOCK");
