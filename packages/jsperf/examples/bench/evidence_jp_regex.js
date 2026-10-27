"use strict";
/**
 * jp-regex-ctor-hot: new RegExp("a+") once vs every test of one fixed string.
 * Warm 3, median of 9. Writes JSONL only when EVIDENCE_DIR is set.
 */
const fs = require("fs");
const path = require("path");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.RE_N || 20000);
const TEXT = "aaa-bbb";
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

function once() {
  const re = new RegExp("a+");
  let n = 0;
  for (let i = 0; i < N; i++) if (re.test(TEXT)) n++;
  return n;
}
function each() {
  let n = 0;
  for (let i = 0; i < N; i++) {
    const re = new RegExp("a+");
    if (re.test(TEXT)) n++;
  }
  return n;
}

const onceMs = timeMany("regexp_once", once);
const eachMs = timeMany("regexp_each_iter", each);
const node = process.version;
const v8 = process.versions.v8;
const ts = new Date().toISOString();
const rows = [
  { rule: "jp-regex-ctor-hot", case: "regexp_once", role: "after", node, v8, median_ms: Number(onceMs.toFixed(6)), ops: N, ratio: 1, ts },
  { rule: "jp-regex-ctor-hot", case: "regexp_each_iter", role: "before", node, v8, median_ms: Number(eachMs.toFixed(6)), ops: N, ratio: Number((eachMs / onceMs).toFixed(6)), ts },
];
if (OUT_DIR) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const p = path.join(OUT_DIR, "jp-regex-ctor-hot.jsonl");
  fs.writeFileSync(p, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log("wrote " + p);
}
console.log("node=%s regex=%s", node, (eachMs / onceMs).toFixed(3));
console.log("DONE_NODE_REGEX");
