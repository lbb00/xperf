"use strict";
/**
 * jp-dom-query-in-loop: querySelector(".item") once vs every pass on a one-element document.
 * linkedom, not a browser. Both sides read textContent. Warm 3, median of 9.
 */
const fs = require("fs");
const path = require("path");
const { parseHTML } = require("linkedom");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.DOM_N || 20000);
const OUT_DIR = process.env.EVIDENCE_DIR || "";
const { document } = parseHTML('<div class="item">ok</div>');

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

function queryOnce() {
  const node = document.querySelector(".item");
  let n = 0;
  for (let i = 0; i < N; i++) n += node ? node.textContent.length : 0;
  return n;
}
function queryEach() {
  let n = 0;
  for (let i = 0; i < N; i++) {
    const node = document.querySelector(".item");
    n += node ? node.textContent.length : 0;
  }
  return n;
}

const onceMs = timeMany("query_once", queryOnce);
const eachMs = timeMany("query_each_iter", queryEach);
const node = process.version;
const v8 = process.versions.v8;
const ts = new Date().toISOString();
const rows = [
  { rule: "jp-dom-query-in-loop", case: "query_once", role: "after", node, v8, median_ms: Number(onceMs.toFixed(3)), ops: N, ratio: 1, ts },
  { rule: "jp-dom-query-in-loop", case: "query_each_iter", role: "before", node, v8, median_ms: Number(eachMs.toFixed(3)), ops: N, ratio: Number((eachMs / onceMs).toFixed(3)), ts },
];
if (OUT_DIR) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const p = path.join(OUT_DIR, "jp-dom-query-in-loop.jsonl");
  fs.writeFileSync(p, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log("wrote " + p);
}
console.log("node=%s dom=%s", node, (eachMs / onceMs).toFixed(3));
console.log("DONE_NODE_DOM");
