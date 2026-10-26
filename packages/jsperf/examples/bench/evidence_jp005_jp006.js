"use strict";
/**
 * Evidence microbench for jp-string-plus-in-loop and jp-map-filter-chain.
 *
 * String cases compare the lint's prescribed rewrite (push + join) with +=.
 * The matcher only sees += of a string literal or String.fromCharCode.
 * Map/filter cases compare a chain with one loop. Cost is expected to track length.
 *
 * Writes JSONL for the string cases under evidence/_removed/ (the prescribed
 * join rewrite missed the ~2× gate) and for the chain cases under evidence/.
 */
const fs = require("fs");
const path = require("path");

const ROUNDS = 9;
const WARM = 3;
const OUT_DIR =
  process.env.EVIDENCE_DIR || path.join(__dirname, "..", "..", "evidence");

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

function repeat(fn, reps) {
  return function timed() {
    let s = 0;
    for (let i = 0; i < reps; i++) s = (s + (fn() | 0)) | 0;
    return s;
  };
}

/* --- string += vs push+join. Result length is consumed so both flatten. --- */

function plusNl(n) {
  let s = "";
  for (let i = 0; i < n; i++) s += "\n";
  return s.length;
}
function joinNl(n) {
  const parts = [];
  for (let i = 0; i < n; i++) parts.push("\n");
  return parts.join("").length;
}
function plusBig(n) {
  let s = "";
  for (let i = 0; i < n; i++) {
    s += "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
  }
  return s.length;
}
function joinBig(n) {
  const parts = [];
  for (let i = 0; i < n; i++) {
    parts.push("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
  }
  return parts.join("").length;
}
function plusFromChar(n) {
  let s = "";
  for (let i = 0; i < n; i++) s += String.fromCharCode(97 + (i % 26));
  return s.length;
}
function joinFromChar(n) {
  const parts = [];
  for (let i = 0; i < n; i++) parts.push(String.fromCharCode(97 + (i % 26)));
  return parts.join("").length;
}
function plusCharVar(n, ch) {
  let s = "";
  for (let i = 0; i < n; i++) s += ch;
  return s.length;
}
function joinCharVar(n, ch) {
  const parts = [];
  for (let i = 0; i < n; i++) parts.push(ch);
  return parts.join("").length;
}
function plusProp(n) {
  const obj = { s: "" };
  for (let i = 0; i < n; i++) obj.s += "\n";
  return obj.s.length;
}
function joinProp(n) {
  const parts = [];
  for (let i = 0; i < n; i++) parts.push("\n");
  return parts.join("").length;
}

/* --- map/filter chain vs one pass --- */

function makeRows(n) {
  const rows = new Array(n);
  for (let i = 0; i < n; i++) {
    rows[i] = {
      a: (i & 1) === 0,
      b: (i & 3) !== 1,
      c: (i % 5) !== 0,
      d: (i % 7) !== 0,
      v: i,
    };
  }
  return rows;
}

function sumOut(out) {
  let s = 0;
  for (let i = 0; i < out.length; i++) s = (s + out[i]) | 0;
  return s;
}
function chain2(rows) {
  const filtered = rows.filter((r) => r.a);
  return sumOut(filtered.map((r) => r.v));
}
function one2(rows) {
  const out = [];
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    if (r.a) out.push(r.v);
  }
  return sumOut(out);
}
function chain4(rows) {
  return sumOut(
    rows
      .filter((r) => r.a)
      .filter((r) => r.b)
      .filter((r) => r.c)
      .filter((r) => r.d)
      .map((r) => r.v)
  );
}
function one4(rows) {
  const out = [];
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    if (r.a && r.b && r.c && r.d) out.push(r.v);
  }
  return sumOut(out);
}

function report(rows) {
  const nameW = 28;
  process.stdout.write(
    "case".padEnd(nameW) +
      "plus_or_chain_ms".padStart(18) +
      "join_or_one_ms".padStart(16) +
      "ratio".padStart(10) +
      "  note\n"
  );
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const ratio = r.after === 0 ? 0 : r.before / r.after;
    process.stdout.write(
      r.case.padEnd(nameW) +
        r.before.toFixed(3).padStart(18) +
        r.after.toFixed(3).padStart(16) +
        ratio.toFixed(3).padStart(10) +
        "  " +
        r.note +
        "\n"
    );
  }
  process.stdout.write("node " + process.version + " v8 " + process.versions.v8 + "\n");
}

function pair(caseName, beforeFn, afterFn, note, ops) {
  const before = timeMany(beforeFn);
  const after = timeMany(afterFn);
  return { case: caseName, before: before, after: after, note: note, ops: ops };
}


function evidenceLine(rule, caseName, role, node, v8, median, ops, ratio, ts) {
  return JSON.stringify({
    rule: rule,
    case: caseName,
    role: role,
    node: node,
    v8: v8,
    median_ms: median,
    ops: ops,
    ratio: ratio,
    ts: ts,
  });
}

function main() {
  const ch = "y";
  const rows3 = makeRows(3);
  const rows100 = makeRows(100);
  const rows35k = makeRows(35000);

  const measured = [
    pair("nl_100_x200", repeat(() => plusNl(100), 200), repeat(() => joinNl(100), 200), "matched: += '\\n'", 100 * 200),
    pair("nl_22000_x20", repeat(() => plusNl(22000), 20), repeat(() => joinNl(22000), 20), "matched: += '\\n'", 22000 * 20),
    pair("nl_44000_x10", repeat(() => plusNl(44000), 10), repeat(() => joinNl(44000), 10), "matched: += '\\n'", 44000 * 10),
    pair("fromChar_22000_x10", repeat(() => plusFromChar(22000), 10), repeat(() => joinFromChar(22000), 10), "matched: fromCharCode", 22000 * 10),
    pair("fromChar_44000_x5", repeat(() => plusFromChar(44000), 5), repeat(() => joinFromChar(44000), 5), "matched: fromCharCode", 44000 * 5),
    pair("big64_700_x40", repeat(() => plusBig(700), 40), repeat(() => joinBig(700), 40), "matched: 64-char literal", 700 * 40),
    pair("prop_22000_x10", repeat(() => plusProp(22000), 10), repeat(() => joinProp(22000), 10), "matched: property += '\\n'", 22000 * 10),
    pair("ident_22000_x20", repeat(() => plusCharVar(22000, ch), 20), repeat(() => joinCharVar(22000, ch), 20), "not matched: += identifier", 22000 * 20),
    pair("chain2_n3_x20000", repeat(() => chain2(rows3), 20000), repeat(() => one2(rows3), 20000), "2-chain, 3 rows", 3 * 20000),
    pair("chain4_n3_x20000", repeat(() => chain4(rows3), 20000), repeat(() => one4(rows3), 20000), "4-filter+map, 3 rows", 3 * 20000),
    pair("chain2_n100_x2000", repeat(() => chain2(rows100), 2000), repeat(() => one2(rows100), 2000), "2-chain, 100 rows", 100 * 2000),
    pair("chain4_n100_x2000", repeat(() => chain4(rows100), 2000), repeat(() => one4(rows100), 2000), "4-filter+map, 100 rows", 100 * 2000),
    pair("chain2_n35000_x20", repeat(() => chain2(rows35k), 20), repeat(() => one2(rows35k), 20), "2-chain, 35000 rows", 35000 * 20),
    pair("chain4_n35000_x20", repeat(() => chain4(rows35k), 20), repeat(() => one4(rows35k), 20), "4-filter+map, 35000 rows", 35000 * 20),
  ];

  report(measured);

  const ts = new Date().toISOString();
  const node = process.version;
  const v8 = process.versions.v8;
  const stringLines = [];
  const chainLines = [];
  for (let i = 0; i < measured.length; i++) {
    const r = measured[i];
    const ratio = r.after === 0 ? 0 : r.before / r.after;
    const rule = r.case.startsWith("chain") ? "jp-map-filter-chain" : "jp-string-plus-in-loop";
    const bucket = rule === "jp-map-filter-chain" ? chainLines : stringLines;
    bucket.push(evidenceLine(rule, r.case, "before", node, v8, r.before, r.ops, ratio, ts));
    bucket.push(evidenceLine(rule, r.case, "after", node, v8, r.after, r.ops, 1, ts));
  }
  const removedDir = path.join(OUT_DIR, "_removed");
  fs.mkdirSync(removedDir, { recursive: true });
  const stringOut = path.join(removedDir, "jp-string-plus-in-loop.jsonl");
  const chainOut = path.join(OUT_DIR, "jp-map-filter-chain.jsonl");
  fs.writeFileSync(stringOut, stringLines.join("\n") + "\n");
  fs.writeFileSync(chainOut, chainLines.join("\n") + "\n");
  process.stdout.write("wrote " + stringOut + "\n");
  process.stdout.write("wrote " + chainOut + "\n");
}

main();
