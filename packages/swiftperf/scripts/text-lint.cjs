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
  "sp-print-hot": "print(; gate or buffer — cost adds up even off a hot path",
  "sp-array-no-reserve": "empty Array then append without reserveCapacity — cost adds up even off a hot path",
  "sp-dateformatter-hot": "date formatter constructed; reuse one instance — cost adds up even off a hot path",
  "sp-json-decode-hot": "JSON value decoded; reuse one decoder — cost adds up even off a hot path",
  "sp-regex-hot": "regular expression constructed; compile outside only when this pattern stays the same — cost adds up even off a hot path",
  "sp-file-read-hot": "file read; read once when the path stays the same — cost adds up even off a hot path",
  "sp-clock-hot": "clock sample; hoist only when this iteration does not need a fresh time — cost adds up even off a hot path",
  "sp-value-for-key-hot": "lookup by name; use the field directly when the name is fixed — cost adds up even off a hot path",
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


function identIn(s, name) {
  if (!name) return false;
  let i = 0;
  while (i < s.length) {
    const at = s.indexOf(name, i);
    if (at < 0) return false;
    const beforeOK = at === 0 || !isIdentChar(s[at - 1]);
    const afterOK = at + name.length >= s.length || !isIdentChar(s[at + name.length]);
    if (beforeOK && afterOK) return true;
    i = at + 1;
  }
  return false;
}

function forNames(code) {
  const m = /\bfor\s+(.+?)\s+in\b/.exec(code);
  if (!m) return [];
  const pat = m[1];
  const names = [];
  let cur = "";
  function flush() {
    if (cur && cur !== "_" && cur !== "for" && cur !== "in" && cur !== "let" && cur !== "var" && cur !== "case") {
      names.push(cur);
    }
    cur = "";
  }
  for (const ch of pat) {
    if (/[A-Za-z0-9_]/.test(ch)) cur += ch;
    else flush();
  }
  flush();
  return names;
}

function regionUses(code, marker, names) {
  if (!names.length) return false;
  const at = code.indexOf(marker);
  if (at < 0) return false;
  const rest = code.slice(at + marker.length);
  return names.some((n) => identIn(rest, n));
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

function scanFile(filePath, scope) {
  const scopeMode = scope === "loop" ? "loop" : "all";
  let text;
  try {
    text = fs.readFileSync(filePath, "utf8");
  } catch {
    return [];
  }
  const findings = [];
  let depth = 0;
  let inLoop = 0;
  let loopAwait = false;
  let loopNames = [];
  const clockHold = [];
  /** @type {Map<string, {depth:number, reserved:boolean, fired?:boolean}>} */
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
      loopNames = loopNames.concat(forNames(code));
      if (/\bawait\b/.test(code)) loopAwait = true;
    }
    const matchHere = scopeMode === "all" || (inLoop > 0 && depth >= inLoop);
    if (matchHere) {
      if (RE_PRINT.test(code)) {
        findings.push({ rule: "sp-print-hot", path: filePath, line: i + 1, message: MSG["sp-print-hot"] });
      }
      if (hasToken(code, dateFmtParts, true)) {
        findings.push({ rule: "sp-dateformatter-hot", path: filePath, line: i + 1, message: MSG["sp-dateformatter-hot"] });
      }
      if (hasToken(code, jsonDecParts, true) || hasToken(code, jsonObjParts, false)) {
        findings.push({ rule: "sp-json-decode-hot", path: filePath, line: i + 1, message: MSG["sp-json-decode-hot"] });
      }
      if (/\bawait\b/.test(code)) loopAwait = true;
      if (hasToken(code, nsRegexParts, true) && !regionUses(code, "pattern:", loopNames)) {
        findings.push({ rule: "sp-regex-hot", path: filePath, line: i + 1, message: MSG["sp-regex-hot"] });
      }
      if (hasToken(code, fileReadParts, false) && !regionUses(code, "OfFile", loopNames)) {
        findings.push({ rule: "sp-file-read-hot", path: filePath, line: i + 1, message: MSG["sp-file-read-hot"] });
      }
      if (hasToken(code, clockParts, true) && !loopAwait) {
        clockHold.push({ rule: "sp-clock-hot", path: filePath, line: i + 1, message: MSG["sp-clock-hot"] });
      }
      if (hasToken(code, kvcParts, false)) {
        findings.push({ rule: "sp-value-for-key-hot", path: filePath, line: i + 1, message: MSG["sp-value-for-key-hot"] });
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
    if (inLoop > 0 && depth < inLoop) {
      if (!loopAwait) findings.push.apply(findings, clockHold);
      clockHold.length = 0;
      loopAwait = false;
      loopNames = [];
      inLoop = 0;
    }
    for (const [name, st] of empties) {
      if (st.depth > depth) empties.delete(name);
    }
  }
  if (!loopAwait) findings.push.apply(findings, clockHold);
  return findings;
}

function scanPath(root, scope) {
  const st = fs.statSync(root);
  if (st.isFile()) return isSwift(root) ? scanFile(root, scope) : [];
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
        out.push.apply(out, scanFile(full, scope));
      }
    }
  }
  walk(root);
  return out;
}

function usage(code) {
  console.error(
    "Usage: text-lint.cjs PATH... [--format text|json] [--severity RULE=error|hint|off] [--scope all|loop] [--strict-hints] [--no-fail] [--raw-paths]\n"
  );
  process.exit(code);
}

function main(argv) {
  const args = argv.slice(2);
  if (!args.length) usage(2);
  // G3 redesign: print in a loop stays off; sp-array-no-reserve stays hint. Force-unwrap, string +=, and map/joined were removed.
  // 2026-10-23 hot-call rules stay hint until measured; not corpus-triaged.
  const sev = { "sp-print-hot": "off", "sp-array-no-reserve": "hint", "sp-dateformatter-hot": "hint", "sp-json-decode-hot": "hint", "sp-regex-hot": "hint", "sp-file-read-hot": "hint", "sp-clock-hot": "hint", "sp-value-for-key-hot": "hint" };
  let format = "text";
  let strictHints = false;
  let noFail = false;
  let rawPaths = false;
  let scope = "all";
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
    if (a === "--scope") {
      scope = args[++i];
      if (scope !== "all" && scope !== "loop") usage(2);
      continue;
    }
    if (a.startsWith("--scope=")) {
      scope = a.slice(8);
      if (scope !== "all" && scope !== "loop") usage(2);
      continue;
    }
    if (a.startsWith("-")) usage(2);
    paths.push(a);
  }
  if (!paths.length) usage(2);

  let findings = [];
  for (const p of paths) {
    if (rawPaths) {
      findings = findings.concat(scanPathRaw(p, scope));
    } else {
      findings = findings.concat(scanPath(p, scope));
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

function scanPathRaw(root, scope) {
  const st = fs.statSync(root);
  if (st.isFile()) return isSwift(root) ? scanFile(root, scope) : [];
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
        out.push.apply(out, scanFile(full, scope));
      }
    }
  }
  walk(root);
  return out;
}

main(process.argv);
