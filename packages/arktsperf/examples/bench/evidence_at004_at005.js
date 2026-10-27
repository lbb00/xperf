"use strict";
/**
 * Evidence microbench for at-includes-hot / at-json-hot → packages/arktsperf/evidence/*.jsonl
 * Node proxy for ArkTS smells (no ArkTS VM on this machine). Document as Node/V8 proxy only.
 * "at-includes-hot": Array.includes / String.indexOf in loop vs Set / Map lookup.
 * "at-json-hot": JSON.parse/stringify per item vs once / reuse.
 */
const fs = require("fs");
const path = require("path");

const ROUNDS = 9;
const WARM = 3;
const N_INC = Number(process.env.AT004_N || 5e4);
const N_IDX = Number(process.env.AT004_IDX_N || 2e5);
const N_JSON = Number(process.env.AT005_N || 2e4);
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

/* --- "at-includes-hot": includes in loop vs Set --- */
const known = [];
for (let i = 0; i < 256; i++) known.push("k" + (i % 64));
const items = [];
for (let i = 0; i < N_INC; i++) items.push("k" + (i % 128));

function case_includes_loop() {
  let n = 0;
  for (let i = 0; i < items.length; i++) {
    if (known.includes(items[i])) n++;
  }
  return n;
}
function case_set_has() {
  const set = new Set(known);
  let n = 0;
  for (let i = 0; i < items.length; i++) {
    if (set.has(items[i])) n++;
  }
  return n;
}

/* --- "at-includes-hot": indexOf alphabet vs Map --- */
const alphabet =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const chars = [];
for (let i = 0; i < N_IDX; i++) chars.push(alphabet[i % alphabet.length]);

function case_indexOf_loop() {
  let s = 0;
  for (let i = 0; i < chars.length; i++) {
    s = (s + alphabet.indexOf(chars[i])) | 0;
  }
  return s;
}
function case_map_lookup() {
  const map = new Map();
  for (let i = 0; i < alphabet.length; i++) map.set(alphabet[i], i);
  let s = 0;
  for (let i = 0; i < chars.length; i++) {
    s = (s + map.get(chars[i])) | 0;
  }
  return s;
}

/* --- "at-json-hot": JSON.parse in loop vs once --- */
const payloads = [];
for (let i = 0; i < N_JSON; i++) {
  payloads.push(JSON.stringify({ i: i & 1023, s: "x" + (i % 16) }));
}
const oneBig = JSON.stringify(
  payloads.map((_, i) => ({ i: i & 1023, s: "x" + (i % 16) }))
);

function case_parse_in_loop() {
  let s = 0;
  for (let i = 0; i < payloads.length; i++) {
    const o = JSON.parse(payloads[i]);
    s = (s + o.i) | 0;
  }
  return s;
}
function case_parse_once_array() {
  const arr = JSON.parse(oneBig);
  let s = 0;
  for (let i = 0; i < arr.length; i++) s = (s + arr[i].i) | 0;
  return s;
}

function case_stringify_in_loop() {
  const rows = [];
  for (let i = 0; i < N_JSON; i++) rows.push({ i: i & 1023 });
  let s = 0;
  for (let i = 0; i < rows.length; i++) {
    s = (s + JSON.stringify(rows[i]).length) | 0;
  }
  return s;
}
function case_stringify_once() {
  const rows = [];
  for (let i = 0; i < N_JSON; i++) rows.push({ i: i & 1023 });
  const blob = JSON.stringify(rows);
  return blob.length;
}

function emit(rule, pairs) {
  const afterMed = pairs.find((p) => p.role === "after").median_ms;
  const lines = pairs.map((p) =>
    JSON.stringify({
      rule,
      case: p.case,
      role: p.role,
      runtime: "node-proxy",
      note: "Not ArkTS VM; V8/Node stand-in for same smell",
      node: process.version,
      v8: process.versions.v8,
      median_ms: p.median_ms,
      ops: p.ops,
      ratio: p.median_ms / afterMed,
      ts: new Date().toISOString(),
    })
  );
  const out = path.join(OUT_DIR, rule + ".jsonl");
  fs.writeFileSync(out, lines.join("\n") + "\n");
  console.log("wrote", out);
  for (const p of pairs) {
    console.log(
      " ",
      p.role,
      p.case,
      p.median_ms.toFixed(3),
      "ms ratio",
      (p.median_ms / afterMed).toFixed(3)
    );
  }
}

const node = process.version;
console.log("Node", node, "V8", process.versions.v8);

{
  const includes_ms = timeMany(case_includes_loop);
  const set_ms = timeMany(case_set_has);
  const idx_ms = timeMany(case_indexOf_loop);
  const map_ms = timeMany(case_map_lookup);
  // emit two after baselines separately by writing custom
  const afterInc = set_ms;
  const lines = [
    {
      rule: "at-includes-hot",
      case: "set_has",
      role: "after",
      median_ms: set_ms,
      ops: N_INC,
      ratio: 1,
    },
    {
      rule: "at-includes-hot",
      case: "includes_loop",
      role: "before",
      median_ms: includes_ms,
      ops: N_INC,
      ratio: includes_ms / set_ms,
    },
    {
      rule: "at-includes-hot",
      case: "map_lookup",
      role: "after",
      median_ms: map_ms,
      ops: N_IDX,
      ratio: 1,
    },
    {
      rule: "at-includes-hot",
      case: "indexOf_loop",
      role: "before",
      median_ms: idx_ms,
      ops: N_IDX,
      ratio: idx_ms / map_ms,
    },
  ].map((p) =>
    JSON.stringify({
      ...p,
      runtime: "node-proxy",
      note: "Not ArkTS VM; V8/Node stand-in for same smell",
      node: process.version,
      v8: process.versions.v8,
      ts: new Date().toISOString(),
    })
  );
  const out = path.join(OUT_DIR, "at-includes-hot.jsonl");
  fs.writeFileSync(out, lines.join("\n") + "\n");
  console.log("wrote", out);
  console.log(" includes", includes_ms, "set", set_ms, "ratio", includes_ms / set_ms);
  console.log(" indexOf", idx_ms, "map", map_ms, "ratio", idx_ms / map_ms);
}

{
  const parse_loop = timeMany(case_parse_in_loop);
  const parse_once = timeMany(case_parse_once_array);
  const str_loop = timeMany(case_stringify_in_loop);
  const str_once = timeMany(case_stringify_once);
  const lines = [
    {
      case: "parse_once_array",
      role: "after",
      median_ms: parse_once,
      ops: N_JSON,
      ratio: 1,
    },
    {
      case: "parse_in_loop",
      role: "before",
      median_ms: parse_loop,
      ops: N_JSON,
      ratio: parse_loop / parse_once,
    },
    {
      case: "stringify_once",
      role: "after",
      median_ms: str_once,
      ops: N_JSON,
      ratio: 1,
    },
    {
      case: "stringify_in_loop",
      role: "before",
      median_ms: str_loop,
      ops: N_JSON,
      ratio: str_loop / str_once,
    },
  ].map((p) =>
    JSON.stringify({
      rule: "at-json-hot",
      ...p,
      runtime: "node-proxy",
      note: "Not ArkTS VM; V8/Node stand-in for same smell",
      node: process.version,
      v8: process.versions.v8,
      ts: new Date().toISOString(),
    })
  );
  const out = path.join(OUT_DIR, "at-json-hot.jsonl");
  fs.writeFileSync(out, lines.join("\n") + "\n");
  console.log("wrote", out);
  console.log(" parse_loop", parse_loop, "once", parse_once, "ratio", parse_loop / parse_once);
  console.log(" stringify_loop", str_loop, "once", str_once, "ratio", str_loop / str_once);
}
