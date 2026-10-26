"use strict";
/**
 * Evidence microbench for jp-alloc-in-loop / jp-console-in-loop → packages/jsperf/evidence/*.jsonl
 * jp-alloc-in-loop kernels match static_vs_v8_correlate.js case 5 (+ push vs prealloc).
 * "jp-console-in-loop": console.log in loop vs quiet loop (stdout discarded so the run is
 * not TTY-bound; see jp-console-in-loop.md for env limits).
 */
const fs = require("fs");
const path = require("path");
const { Writable } = require("stream");

const ROUNDS = 9;
const WARM = 3;
const N = Number(process.env.CORR_N || 2e5);
const N_CONSOLE = Number(process.env.CONSOLE_N || 2e4);
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

/* --- jp-alloc-in-loop --- */
function case_new_in_loop() {
  let s = 0;
  for (let i = 0; i < N; i++) {
    const buf = new Uint8Array(16);
    buf[0] = i & 255;
    s = (s + buf[0]) | 0;
  }
  return s;
}
function case_new_once() {
  const buf = new Uint8Array(16);
  let s = 0;
  for (let i = 0; i < N; i++) {
    buf[0] = i & 255;
    s = (s + buf[0]) | 0;
  }
  return s;
}
function case_push_object() {
  const a = [];
  for (let i = 0; i < N; i++) {
    a.push({ i: i & 1023 });
  }
  let s = 0;
  for (let i = 0; i < a.length; i++) s = (s + a[i].i) | 0;
  return s;
}
function case_prealloc_fill() {
  const a = new Array(N);
  for (let i = 0; i < N; i++) {
    a[i] = i & 1023;
  }
  let s = 0;
  for (let i = 0; i < N; i++) s = (s + a[i]) | 0;
  return s;
}

/* --- jp-console-in-loop --- */
function withDiscardStdout(fn) {
  const discard = new Writable({
    write(_chunk, _enc, cb) {
      cb();
    },
  });
  const oldWrite = process.stdout.write;
  process.stdout.write = function discardWrite(chunk, enc, cb) {
    return discard.write(chunk, enc, cb);
  };
  try {
    return fn();
  } finally {
    process.stdout.write = oldWrite;
  }
}

function case_console_in_loop() {
  return withDiscardStdout(() => {
    let s = 0;
    for (let i = 0; i < N_CONSOLE; i++) {
      console.log(i);
      s = (s + i) | 0;
    }
    return s;
  });
}
function case_quiet_loop() {
  let s = 0;
  for (let i = 0; i < N_CONSOLE; i++) {
    s = (s + i) | 0;
  }
  return s;
}
function case_console_once_after() {
  return withDiscardStdout(() => {
    let s = 0;
    for (let i = 0; i < N_CONSOLE; i++) {
      s = (s + i) | 0;
    }
    console.log("done", s);
    return s;
  });
}

const ts = new Date().toISOString();
const node = process.version;
const v8 = process.versions.v8;

fs.mkdirSync(OUT_DIR, { recursive: true });

const newOnce = timeMany(case_new_once);
const newLoop = timeMany(case_new_in_loop);
const prealloc = timeMany(case_prealloc_fill);
const pushObj = timeMany(case_push_object);
const quiet = timeMany(case_quiet_loop);
const consoleOnce = timeMany(case_console_once_after);
const consoleLoop = timeMany(case_console_in_loop);

const jp001 = [
  {
    rule: "jp-alloc-in-loop",
    case: "new_once_outside",
    role: "after",
    node,
    v8,
    median_ms: newOnce,
    ops: N,
    ratio: 1,
    ts,
  },
  {
    rule: "jp-alloc-in-loop",
    case: "new_in_loop",
    role: "before",
    node,
    v8,
    median_ms: newLoop,
    ops: N,
    ratio: newLoop / newOnce,
    ts,
  },
  {
    rule: "jp-alloc-in-loop",
    case: "prealloc_fill_sum",
    role: "after",
    node,
    v8,
    median_ms: prealloc,
    ops: N,
    ratio: 1,
    ts,
  },
  {
    rule: "jp-alloc-in-loop",
    case: "push_object_literal",
    role: "before",
    node,
    v8,
    median_ms: pushObj,
    ops: N,
    ratio: pushObj / prealloc,
    ts,
  },
];

const jp002 = [
  {
    rule: "jp-console-in-loop",
    case: "quiet_loop",
    role: "after",
    node,
    v8,
    median_ms: quiet,
    ops: N_CONSOLE,
    ratio: 1,
    ts,
  },
  {
    rule: "jp-console-in-loop",
    case: "console_once_after",
    role: "after",
    node,
    v8,
    median_ms: consoleOnce,
    ops: N_CONSOLE,
    ratio: consoleOnce / quiet,
    ts,
  },
  {
    rule: "jp-console-in-loop",
    case: "console_log_in_loop",
    role: "before",
    node,
    v8,
    median_ms: consoleLoop,
    ops: N_CONSOLE,
    ratio: consoleLoop / quiet,
    ts,
  },
];

function writeRule(id, rows) {
  const p = path.join(OUT_DIR, id + ".jsonl");
  fs.writeFileSync(p, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  const before = rows.find((r) => r.role === "before");
  console.log(
    "%s wrote %s primary_ratio_before/after=%s",
    id,
    p,
    before ? before.ratio.toFixed(3) : "?"
  );
}

writeRule("jp-alloc-in-loop", jp001);
writeRule("jp-console-in-loop", jp002);
console.log(
  "node=%s v8=%s N=%d N_CONSOLE=%d new_loop/once=%s push/prealloc=%s console/quiet=%s",
  node,
  v8,
  N,
  N_CONSOLE,
  (newLoop / newOnce).toFixed(3),
  (pushObj / prealloc).toFixed(3),
  (consoleLoop / quiet).toFixed(3)
);
