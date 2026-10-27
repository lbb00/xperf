"use strict";
/**
 * jp-json-hot: JSON.parse of one fixed text, once vs every pass.
 * Warm 3, median of 9. Writes JSONL only when EVIDENCE_DIR is set.
 */
const fs = require("fs");
const path = require("path");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.JSON_N || 20000);
const TEXT = '{"n":1,"s":"hello"}';
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
    name + " median_ms=" + med.toFixed(3) + " samples " + samples.map((s) => s.toFixed(3)).join(" ")
  );
  return med;
}

function parseOnce() {
  const row = JSON.parse(TEXT);
  let n = 0;
  for (let i = 0; i < N; i++) n = (n + row.n) | 0;
  return n;
}
function parseEach() {
  let n = 0;
  for (let i = 0; i < N; i++) n = (n + JSON.parse(TEXT).n) | 0;
  return n;
}

const onceMs = timeMany("parse_once", parseOnce);
const eachMs = timeMany("parse_each_iter", parseEach);
const node = process.version;
const v8 = process.versions.v8;
const ts = new Date().toISOString();
const rows = [
  { rule: "jp-json-hot", case: "parse_once", role: "after", node, v8, median_ms: Number(onceMs.toFixed(6)), ops: N, ratio: 1, ts },
  { rule: "jp-json-hot", case: "parse_each_iter", role: "before", node, v8, median_ms: Number(eachMs.toFixed(6)), ops: N, ratio: Number((eachMs / onceMs).toFixed(6)), ts },
];
if (OUT_DIR) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const p = path.join(OUT_DIR, "jp-json-hot.jsonl");
  fs.writeFileSync(p, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log("wrote " + p);
}
console.log("node=%s json=%s", node, (eachMs / onceMs).toFixed(3));
console.log("DONE_NODE_JSON");
