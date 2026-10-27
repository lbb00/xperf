"use strict";
/**
 * Correlation: static JP-like smells vs measured V8 wall time (+ optional deopt count via env).
 * Not a lint rule. Writes JSON summary to stdout; JSONL when RESULTS_JSONL set.
 */
const fs = require("fs");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.CORR_N || 2e5);

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
  return { median_ms: median(samples), samples, sink };
}

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
function hotLoad(o) {
  return o.x + o.y + o.z;
}

/* Case 1 */
function case1_mono() {
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + hotLoad(makeMono(i & 1023, (i + 1) & 1023))) | 0;
  return s;
}
function case1_poly() {
  let s = 0;
  for (let i = 0; i < N; i++)
    s = (s + hotLoad(makePoly(i & 1, i & 1023, (i + 1) & 1023))) | 0;
  return s;
}

/* Case 2: packed vs holey delete */
function case2_packed() {
  const a = new Array(N);
  for (let i = 0; i < N; i++) a[i] = i & 1023;
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + a[i]) | 0;
  return s;
}
function case2_holey_delete() {
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

/* Case 3: typed vs holey number[] */
function case3_typed() {
  const a = new Float64Array(N);
  for (let i = 0; i < N; i++) a[i] = (i & 1023) * 0.5;
  let s = 0;
  for (let i = 0; i < N; i++) s += a[i];
  return s | 0;
}
function case3_holey_number() {
  const a = new Array(N);
  for (let i = 0; i < N; i += 2) a[i] = (i & 1023) * 0.5;
  let s = 0;
  for (let i = 0; i < N; i++) {
    const v = a[i];
    if (v !== undefined) s += v;
  }
  return s | 0;
}

/* Case 4: delete vs tombstone on hot object */
function case4_delete() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    const o = { k: i & 1023, keep: 1 };
    delete o.k;
    s = (s + (o.keep | 0) + (o.k === undefined ? 0 : o.k)) | 0;
  }
  return s;
}
function case4_tombstone() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    const o = { k: i & 1023, keep: 1 };
    o.k = undefined;
    s = (s + (o.keep | 0) + (o.k === undefined ? 0 : o.k)) | 0;
  }
  return s;
}

/* Case 5 control: new in loop (jp-alloc-hot smell) vs new once outside */
function case5_new_in_loop() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    const buf = new Uint8Array(16);
    buf[0] = i & 255;
    s = (s + buf[0]) | 0;
  }
  return s;
}
function case5_new_once() {
  const buf = new Uint8Array(16);
  let s = 0;
  for (let i = 0; i < N; i++) {
    buf[0] = i & 255;
    s = (s + buf[0]) | 0;
  }
  return s;
}

const cases = [
  {
    id: 1,
    name: "shape_mono_vs_poly",
    a_label: "mono",
    b_label: "poly",
    static_a: false,
    static_b: true,
    static_note: "poly divergent props = shape smell; mono clean",
    a: case1_mono,
    b: case1_poly,
  },
  {
    id: 2,
    name: "packed_vs_holey_delete",
    a_label: "packed",
    b_label: "holey_delete",
    static_a: false,
    static_b: true,
    static_note: "jp-delete-array-hole-like delete a[i]",
    a: case2_packed,
    b: case2_holey_delete,
  },
  {
    id: 3,
    name: "typed_vs_holey_number",
    a_label: "Float64Array",
    b_label: "holey_number[]",
    static_a: false,
    static_b: true,
    static_note: "holey sparse assign smell; typed preferred for numeric",
    a: case3_typed,
    b: case3_holey_number,
  },
  {
    id: 4,
    name: "delete_vs_tombstone",
    a_label: "tombstone_undefined",
    b_label: "delete_obj_k",
    static_a: false,
    static_b: true,
    static_note: "jp-delete-shape delete obj.k vs = undefined",
    a: case4_tombstone,
    b: case4_delete,
  },
  {
    id: 5,
    name: "new_in_loop_vs_once",
    a_label: "new_once_outside",
    b_label: "new_in_loop",
    static_a: false,
    static_b: true,
    static_note: "jp-alloc-hot flags new-in-loop; once-outside not flagged",
    a: case5_new_once,
    b: case5_new_in_loop,
  },
];

const results = [];
console.log(
  "static_vs_v8_correlate node=%s v8=%s N=%d rounds=%d warm=%d",
  process.version,
  process.versions.v8,
  N,
  ROUNDS,
  WARM
);

for (const c of cases) {
  const ra = timeMany(c.a);
  const rb = timeMany(c.b);
  const ratio = rb.median_ms / ra.median_ms;
  const row = {
    id: c.id,
    name: c.name,
    node: process.version,
    v8: process.versions.v8,
    N,
    a_label: c.a_label,
    b_label: c.b_label,
    static_smell_a: c.static_a,
    static_smell_b: c.static_b,
    static_note: c.static_note,
    a_median_ms: ra.median_ms,
    b_median_ms: rb.median_ms,
    ratio_b_over_a: ratio,
  };
  results.push(row);
  console.log(
    "case%d %s: %s=%sms %s=%sms ratio_b/a=%s static_b_smell=%s",
    c.id,
    c.name,
    c.a_label,
    ra.median_ms.toFixed(3),
    c.b_label,
    rb.median_ms.toFixed(3),
    ratio.toFixed(3),
    c.static_b
  );
}

const out = process.env.RESULTS_JSONL;
if (out) {
  for (const row of results) {
    fs.appendFileSync(out, JSON.stringify(Object.assign({ bench: "static_vs_v8" }, row)) + "\n");
  }
}
fs.writeFileSync(
  process.env.CORR_JSON || "/tmp/static-vs-v8.json",
  JSON.stringify({ node: process.version, v8: process.versions.v8, N, results }, null, 2)
);
