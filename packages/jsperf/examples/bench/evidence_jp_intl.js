"use strict";
/**
 * jp-intl-datetimeformat-in-loop: one formatter vs new Intl.DateTimeFormat each pass.
 * Both sides still format. Warm 3, median of 9.
 */
const fs = require("fs");
const path = require("path");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.INTL_N || 2000);
const OUT_DIR = process.env.EVIDENCE_DIR || "";
const rowsIn = [];
for (let i = 0; i < N; i++) rowsIn.push(Date.UTC(2020, 0, 1) + i * 86400000);

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

function formatOnce() {
  const fmt = new Intl.DateTimeFormat("en-US");
  let n = 0;
  for (let i = 0; i < rowsIn.length; i++) n += fmt.format(new Date(rowsIn[i])).length;
  return n;
}
function formatEach() {
  let n = 0;
  for (let i = 0; i < rowsIn.length; i++) {
    const fmt = new Intl.DateTimeFormat("en-US");
    n += fmt.format(new Date(rowsIn[i])).length;
  }
  return n;
}

const onceMs = timeMany("format_once", formatOnce);
const eachMs = timeMany("format_ctor_each_iter", formatEach);
const node = process.version;
const v8 = process.versions.v8;
const ts = new Date().toISOString();
const rows = [
  { rule: "jp-intl-datetimeformat-in-loop", case: "format_once", role: "after", node, v8, median_ms: Number(onceMs.toFixed(3)), ops: N, ratio: 1, ts },
  { rule: "jp-intl-datetimeformat-in-loop", case: "format_ctor_each_iter", role: "before", node, v8, median_ms: Number(eachMs.toFixed(3)), ops: N, ratio: Number((eachMs / onceMs).toFixed(3)), ts },
];
if (OUT_DIR) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const p = path.join(OUT_DIR, "jp-intl-datetimeformat-in-loop.jsonl");
  fs.writeFileSync(p, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log("wrote " + p);
}
console.log("node=%s intl=%s", node, (eachMs / onceMs).toFixed(3));
console.log("DONE_NODE_INTL");
