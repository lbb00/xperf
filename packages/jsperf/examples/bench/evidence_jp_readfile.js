"use strict";
/**
 * jp-readfile-sync-hot: readFileSync of one 1-byte file, once vs every pass.
 * Warm 3, median of 9. Writes JSONL only when EVIDENCE_DIR is set.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.READ_N || 2000);
const OUT_DIR = process.env.EVIDENCE_DIR || "";
const file = path.join(os.tmpdir(), "xperf-one-byte");
fs.writeFileSync(file, "x");

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
    name + " median_ms=" + med.toFixed(3) + " samples " + samples.map((s) => s.toFixed(3)).join(" ")
  );
  return med;
}

function readOnce() {
  const b = fs.readFileSync(file);
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + b[0]) | 0;
  return s;
}
function readEach() {
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + fs.readFileSync(file)[0]) | 0;
  return s;
}

const onceMs = timeMany("read_once", readOnce);
const eachMs = timeMany("read_each_iter", readEach);
const node = process.version;
const v8 = process.versions.v8;
const ts = new Date().toISOString();
const rows = [
  { rule: "jp-readfile-sync-hot", case: "read_once", role: "after", node, v8, median_ms: Number(onceMs.toFixed(3)), ops: N, ratio: 1, ts },
  { rule: "jp-readfile-sync-hot", case: "read_each_iter", role: "before", node, v8, median_ms: Number(eachMs.toFixed(3)), ops: N, ratio: Number((eachMs / onceMs).toFixed(3)), ts },
];
if (OUT_DIR) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const p = path.join(OUT_DIR, "jp-readfile-sync-hot.jsonl");
  fs.writeFileSync(p, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log("wrote " + p);
}
console.log("node=%s read=%s", node, (eachMs / onceMs).toFixed(3));
console.log("DONE_NODE_READ");
