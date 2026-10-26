"use strict";
/**
 * Evidence microbench for jp-delete-shape / jp-delete-array-hole → packages/jsperf/evidence/*.jsonl
 * Reuses the same shapes as static_vs_v8_correlate.js (cases 2 and 4).
 */
const fs = require("fs");
const path = require("path");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.CORR_N || 2e5);
const OUT_DIR =
  process.env.EVIDENCE_DIR ||
  path.join(__dirname, "..", "..", "evidence");

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
    sink = (sink + (fn() | 0)) | 0;
    const t1 = process.hrtime.bigint();
    samples.push(Number(t1 - t0) / 1e6);
  }
  if (sink === Infinity) process.exit(2);
  return median(samples);
}

function case_packed() {
  const a = new Array(N);
  for (let i = 0; i < N; i++) a[i] = i & 1023;
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + a[i]) | 0;
  return s;
}
function case_holey_delete() {
  const a = new Array(N);
  for (let i = 0; i < N; i++) a[i] = i & 1023;
  for (let i = 0; i < N; i += 2) delete a[i];
  let s = 0;
  for (let i = 0; i < N; i++) {
    const v = a[i];
    if (v !== undefined) s = (s + v) | 0;
  }
  return s;
}
function case_delete() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    const o = { k: i & 1023, keep: 1 };
    delete o.k;
    s = (s + (o.keep | 0) + (o.k === undefined ? 0 : o.k)) | 0;
  }
  return s;
}
function case_tombstone() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    const o = { k: i & 1023, keep: 1 };
    o.k = undefined;
    s = (s + (o.keep | 0) + (o.k === undefined ? 0 : o.k)) | 0;
  }
  return s;
}

const ts = new Date().toISOString();
const node = process.version;
const v8 = process.versions.v8;
const ops = N;

fs.mkdirSync(OUT_DIR, { recursive: true });

const packed = timeMany(case_packed);
const holey = timeMany(case_holey_delete);
const tomb = timeMany(case_tombstone);
const del = timeMany(case_delete);

const jp004 = [
  {
    rule: "jp-delete-array-hole",
    case: "packed_fill_sum",
    role: "after",
    node,
    v8,
    median_ms: packed,
    ops,
    ratio: 1,
    ts,
  },
  {
    rule: "jp-delete-array-hole",
    case: "holey_delete_arr_i",
    role: "before",
    node,
    v8,
    median_ms: holey,
    ops,
    ratio: holey / packed,
    ts,
  },
];

const jp003 = [
  {
    rule: "jp-delete-shape",
    case: "tombstone_undefined",
    role: "after",
    node,
    v8,
    median_ms: tomb,
    ops,
    ratio: 1,
    ts,
  },
  {
    rule: "jp-delete-shape",
    case: "delete_obj_k",
    role: "before",
    node,
    v8,
    median_ms: del,
    ops,
    ratio: del / tomb,
    ts,
  },
];

function writeRule(id, rows) {
  const p = path.join(OUT_DIR, id + ".jsonl");
  fs.writeFileSync(p, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log(
    "%s wrote %s ratio_before/after=%s",
    id,
    p,
    rows.find((r) => r.role === "before").ratio.toFixed(3)
  );
}

writeRule("jp-delete-shape", jp003);
writeRule("jp-delete-array-hole", jp004);
console.log("node=%s v8=%s N=%d", node, v8, N);
