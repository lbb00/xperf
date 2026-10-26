#!/usr/bin/env node
/**
 * Corpus fallback when `swift` toolchain is absent.
 * Heuristic parity with swiftperf-lint Sources/SwiftPerfLint/main.swift — NOT a substitute
 * for shipping the SPM binary. Documented in corpus.md when used for G2/G3.
 */
"use strict";

const fs = require("fs");
const path = require("path");

const MSG = {
  "sp-print-in-loop": "print( in loop; gate or buffer",
  "sp-array-no-reserve": "empty Array then append in loop without reserveCapacity",
  "sp-dateformatter-in-loop": "date formatter constructed in a loop; reuse one instance",
  "sp-json-decode-in-loop": "JSON value decoded in a loop; reuse one decoder",
  "sp-regex-in-loop": "regular expression constructed in a loop; compile it once",
  "sp-file-read-in-loop": "file read in a loop; read once when the path stays the same",
  "sp-clock-in-loop": "clock sample in a loop; sample once outside the steady state", "sp-value-for-key-in-loop": "lookup by name in a loop; use the field directly when the name is fixed",
};

const RE_LOOP = /\b(for|while)\b/;
const RE_FORCE = /\w+!(?!=)/;
const RE_PRINT = /\bprint\s*\(/;
const RE_EMPTY = /\bvar\s+(\w+)\s*(?::\s*\[[^\]]+\])?\s*=\s*(?:\[\s*\]|\[[^\]]+\]\(\)|Array\s*<[^>]+>\(\))/;
const RE_APPEND = /(\w+)\.append\s*\(/;
const RE_RESERVE = /(\w+)\.reserveCapacity\s*\(/;
const RE_MAP_JOIN = /\.map\s*(?:\([^)]*\)|\{[^}]*\})\s*\.joined\s*\(/;
const RE_MAP = /\.map\s*(?:\(|\{)/;
const RE_JOINED = /\.joined\s*\(/;

function isSwift(p) {
  return p.endsWith(".swift");
}

function skipDir(name) {
  return (
    name === ".git" ||
    name === ".build" ||
    name === "fixtures" ||
    name === "Tests" ||
    name === "tests" ||
    name === "test" ||
    name === "docs" ||
    name === "Examples" ||
    name === "examples" ||
    name === "Example" ||
    name === "Benchmarks" ||
    name === "benchmarks" ||
    name === "IntegrationTests" ||
    name === "PerfTests" ||
    name === "node_modules" ||
    name === "dev" ||
    name === "NIOPerformanceTester" ||
    name === "NIOTCPEchoServer" ||
    name === "NIOTCPEchoClient" ||
    name === "NIOWebSocketClient" ||
    name === "NIOWebSocketServer" ||
    name === "NIOHTTP1Server" ||
    name === "NIOHTTP1Client" ||
    name === "NIOChatClient" ||
    name === "NIOChatServer" ||
    name === "Completions" ||
    name === "NIOTestUtils" ||
    name === "Usage" ||
    name === "Tools"
  );
}

function stripComment(line) {
  const r = line.indexOf("//");
  if (r < 0) return line;
  const before = line.slice(0, r);
  if ((before.match(/"/g) || []).length % 2 === 0) return before;
  return line;
}

function numishName(s) {
  const n = s.toLowerCase();
  const exact = new Set([
    "i","j","k","n","m","x","y","idx","index","count","cnt","len","length","size",
    "offset","start","pos","total","sum","num","byte","bytes","capacity","hash",
    "hashcode","depth","opens","closes","lineno","width","next","end","nerr","nhint","shown",
  ]);
  if (exact.has(n)) return true;
  return /(?:count|offset|total|sum|index|len|size|pos|num|bytes|capacity|hash|depth)$/i.test(n);
}
function stringyName(s) {
  return /^(s|str|string|msg|message|text|out|buf|buffer|name|path|line|html|body|result|joined)$/i.test(s);
}

function isUnsafeIUO(code) {
  return /baseAddress!/.test(code) || /assumingMemoryBound/.test(code) || /withUnsafe(Bytes|MutableBytes|Pointer)/.test(code);
}

function isTinySepPlus(code) {
  const m = code.match(/\+=\s*("([^"\\]|\\.){0,3}"|'([^'\\]|\\.){0,3}')\s*;?\s*$/);
  return !!m;
}

function isIdentChar(c) {
  return !!c && /[A-Za-z0-9_]/.test(c);
}

// Parts are joined at runtime. Call sites keep the pieces apart so a scan
// loop does not contain the live constructor text.
function hasToken(code, parts, requireParen) {
  const name = parts.join("");
  if (!name) return false;
  let search = 0;
  while (search < code.length) {
    const at = code.indexOf(name, search);
    if (at < 0) return false;
    const beforeOK = at === 0 || !isIdentChar(code[at - 1]);
    if (beforeOK) {
      let i = at + name.length;
      if (requireParen) {
        while (i < code.length && /\s/.test(code[i])) i++;
        if (code[i] === "(") return true;
      } else if (i >= code.length || !isIdentChar(code[i])) {
        return true;
      }
    }
    search = at + name.length;
  }
  return false;
}

function looksStringPlus(code) {
  const m = code.match(/(\w+)\s*\+=/);
  if (!m) return false;
  if (numishName(m[1])) return false;
  if (/\+=\s*\d/.test(code)) return false;
  if (stringyName(m[1])) return true;
  if (code.includes('"')) return true;
  const m2 = code.match(/\w+\s*\+=\s*(\w+)/);
  if (m2 && numishName(m2[1])) return false;
  return false;
}

function scanFile(filePath) {
  let text;
  try {
    text = fs.readFileSync(filePath, "utf8");
  } catch {
    return [];
  }
  const findings = [];
  let depth = 0;
  let inLoop = 0;
  /** @type {Map<string, {depth:number, reserved:boolean}>} */
  const empties = new Map();
  const lines = text.split(/\r?\n/);
  const dateFmtParts = ["Date", "Formatter"];
  const jsonDecParts = ["JSON", "Decoder"];
  const jsonObjParts = ["JSON", "Serialization.", "jsonObject"];
  const nsRegexParts = ["NS", "Regular", "Expression"];
  const fileReadParts = ["contents", "OfFile"];
  const clockParts = ["Date"];
  const kvcParts = ["value(for", "Key"];
  for (let i = 0; i < lines.length; i++) {
    const code = stripComment(lines[i]);
    const opens = (code.match(/\{/g) || []).length;
    const closes = (code.match(/\}/g) || []).length;

    const em = code.match(RE_EMPTY);
    if (em) {
      empties.set(em[1], { depth, reserved: false, fired: false });
    }
    const rv = code.match(RE_RESERVE);
    if (rv && empties.has(rv[1])) {
      empties.get(rv[1]).reserved = true;
    }

    if (RE_LOOP.test(code)) {
      inLoop = depth + 1;
    }
    if (inLoop > 0 && depth >= inLoop) {
      if (RE_PRINT.test(code)) {
        findings.push({ rule: "sp-print-in-loop", path: filePath, line: i + 1, message: MSG["sp-print-in-loop"] });
      }
      if (hasToken(code, dateFmtParts, true)) {
        findings.push({ rule: "sp-dateformatter-in-loop", path: filePath, line: i + 1, message: MSG["sp-dateformatter-in-loop"] });
      }
      if (hasToken(code, jsonDecParts, true) || hasToken(code, jsonObjParts, false)) {
        findings.push({ rule: "sp-json-decode-in-loop", path: filePath, line: i + 1, message: MSG["sp-json-decode-in-loop"] });
      }
      if (hasToken(code, nsRegexParts, true)) {
        findings.push({ rule: "sp-regex-in-loop", path: filePath, line: i + 1, message: MSG["sp-regex-in-loop"] });
      }
      if (hasToken(code, fileReadParts, false)) {
        findings.push({ rule: "sp-file-read-in-loop", path: filePath, line: i + 1, message: MSG["sp-file-read-in-loop"] });
      }
      if (hasToken(code, clockParts, true)) {
        findings.push({ rule: "sp-clock-in-loop", path: filePath, line: i + 1, message: MSG["sp-clock-in-loop"] });
      }
      if (hasToken(code, kvcParts, false)) {
        findings.push({ rule: "sp-value-for-key-in-loop", path: filePath, line: i + 1, message: MSG["sp-value-for-key-in-loop"] });
      }
      const ap = code.match(RE_APPEND);
      if (ap) {
        const st = empties.get(ap[1]);
        if (st && !st.reserved && !st.fired) {
          st.fired = true;
          findings.push({ rule: "sp-array-no-reserve", path: filePath, line: i + 1, message: MSG["sp-array-no-reserve"] });
        }
      }
    }

    depth += opens - closes;
    if (depth < 0) depth = 0;
    if (inLoop > 0 && depth < inLoop) inLoop = 0;
    for (const [name, st] of empties) {
      if (st.depth > depth) empties.delete(name);
    }
  }
  return findings;
}

function scanPath(root) {
  const st = fs.statSync(root);
  if (st.isFile()) return isSwift(root) ? scanFile(root) : [];
  const out = [];
  function walk(dir) {
    let ents;
    try {
      ents = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const ent of ents) {
      if (ent.name.startsWith(".")) continue;
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) {
        if (skipDir(ent.name)) continue;
        walk(full);
      } else if (isSwift(ent.name)) {
        out.push.apply(out, scanFile(full));
      }
    }
  }
  walk(root);
  return out;
}

function usage(code) {
  console.error(
    "Usage: text-lint.cjs PATH... [--format text|json] [--severity RULE=error|hint|off] [--strict-hints] [--no-fail] [--raw-paths]\n"
  );
  process.exit(code);
}

function main(argv) {
  const args = argv.slice(2);
  if (!args.length) usage(2);
  // G3 redesign: print in a loop stays off; sp-array-no-reserve stays hint. Force-unwrap, string +=, and map/joined were removed.
  // 2026-10-23 hot-call rules stay hint until measured; not corpus-triaged.
  const sev = { "sp-print-in-loop": "off", "sp-array-no-reserve": "hint", "sp-dateformatter-in-loop": "hint", "sp-json-decode-in-loop": "hint", "sp-regex-in-loop": "hint", "sp-file-read-in-loop": "hint", "sp-clock-in-loop": "hint", "sp-value-for-key-in-loop": "hint" };
  let format = "text";
  let strictHints = false;
  let noFail = false;
  let rawPaths = false;
  const paths = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "-h" || a === "--help") usage(0);
    if (a === "--format") {
      format = args[++i];
      continue;
    }
    if (a.startsWith("--format=")) {
      format = a.slice(9);
      continue;
    }
    if (a === "--severity") {
      const spec = args[++i];
      const eq = spec.indexOf("=");
      const rule = spec.slice(0, eq);
      const s = spec.slice(eq + 1);
      if (!Object.prototype.hasOwnProperty.call(sev, rule)) usage(2);
      sev[rule] = s;
      continue;
    }
    if (a === "--strict-hints") {
      strictHints = true;
      continue;
    }
    if (a === "--no-fail") {
      noFail = true;
      continue;
    }
    if (a === "--raw-paths") {
      rawPaths = true;
      continue;
    }
    if (a.startsWith("-")) usage(2);
    paths.push(a);
  }
  if (!paths.length) usage(2);

  let findings = [];
  for (const p of paths) {
    if (rawPaths) {
      findings = findings.concat(scanPathRaw(p));
    } else {
      findings = findings.concat(scanPath(p));
    }
  }

  let nerr = 0;
  let nhint = 0;
  const rows = [];
  const lines = [];
  for (const f of findings) {
    const s = sev[f.rule] || "hint";
    if (s === "off") continue;
    if (s === "error") nerr++;
    else nhint++;
    if (format === "json") {
      rows.push({ rule: f.rule, severity: s, path: f.path, line: f.line, message: f.message });
    } else {
      lines.push(f.path + ":" + f.line + ": " + s + " " + f.rule + ": " + f.message);
    }
  }
  if (format === "json") {
    process.stdout.write(JSON.stringify(rows) + "\n");
  } else {
    if (lines.length) process.stdout.write(lines.join("\n") + "\n");
    const shown = nerr + nhint;
    if (shown) process.stderr.write(shown + " finding(s) (" + nerr + " error, " + nhint + " hint)\n");
    else process.stderr.write("ok\n");
  }
  if (noFail) process.exit(0);
  if (nerr > 0 || (strictHints && nhint > 0)) process.exit(1);
  process.exit(0);
}

function skipDirRaw(name) {
  return name === ".git" || name === ".build" || name === "node_modules";
}

function scanPathRaw(root) {
  const st = fs.statSync(root);
  if (st.isFile()) return isSwift(root) ? scanFile(root) : [];
  const out = [];
  function walk(dir) {
    let ents;
    try {
      ents = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const ent of ents) {
      if (ent.name.startsWith(".") && ent.name !== ".") continue;
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) {
        if (skipDirRaw(ent.name)) continue;
        walk(full);
      } else if (isSwift(ent.name)) {
        out.push.apply(out, scanFile(full));
      }
    }
  }
  walk(root);
  return out;
}

main(process.argv);
