"use strict";

const fs = require("fs");
const path = require("path");

function readSource(filePath) {
  return fs.readFileSync(filePath, "utf8");
}


const EXTS = new Set([".js", ".mjs", ".cjs", ".ts", ".tsx"]);

const RE_LOOP = /\b(for|while|do)\b/;
const RE_PUSH_ALLOC = /\.push\s*\(\s*[{\[]/;
const RE_ASSIGN_NONEMPTY = /(const|let|var)\s+\w+\s*=\s*(\{\s*[^\s}]|\[\s*[^\s\]])/;
const RE_OBJECT_CREATE = /Object\.create\s*\(/;
const RE_NEW_CTOR = /\bnew\s+([A-Za-z_$][\w$]*)/g;
const RE_ERROR_CTOR =
  /^(Error|TypeError|RangeError|SyntaxError|URIError|EvalError|AggregateError|ReferenceError|ERR_[A-Z0-9_]+)$/;
const RE_CONSOLE = /console\.(log|debug|info|warn|error)\s*\(/;
const RE_DELETE = /\bdelete\s+[\w$.]+\s*[;\n]/;
/* "jp-delete-array-hole": only numeric / classic index idents — not delete map[key] (that is jp-delete-shape). G3 FP on Node. */
const RE_DELETE_ARRAY_INDEX =
  /\bdelete\s+[\w$.]+\s*\[\s*(?:\d+|[ij]|idx|index)\s*\]/;
/* Computed key on ordinary objects — shape change, not holey elements */
const RE_DELETE_COMPUTED = /\bdelete\s+[\w$.]+\s*\[/;

const MSG_JP001 = "allocation-like pattern in loop; reuse buffers or typed arrays";
const MSG_JP002 = "console.* in loop; remove or gate off hot path";
const MSG_JP003 = "delete changes object shape; prefer undefined or a denser structure";
const MSG_JP004 = "delete arr[i] makes arrays holey; prefer splice, filter, or dense tombstones";
const MSG_JP006 =
  "chained map/filter; cost grows with array length. One pass was faster on long arrays in the bench; a handful of elements is a different cost";
const MSG_JP007 =
  "new RegExp in a loop; the bench compiled one unchanged pattern. Hoist only when this pattern stays the same";
const MSG_JP008 =
  "JSON.parse/stringify in a loop; the bench repeated one unchanged text. Hoist only when this text stays the same";
const MSG_JP009 =
  "querySelector/getElementById in a loop; the bench repeated one unchanged selector. Cache the node only when the selector stays the same";
const RE_NEW_REGEXP = /\bnew\s+RegExp\s*\(/;
const RE_NEW_REGEXP_ARG = /\bnew\s+RegExp\s*\(\s*([^)]*)/;
const RE_JSON = /\bJSON\.(parse|stringify)\s*\(/;
const RE_JSON_ARG = /\bJSON\.(?:parse|stringify)\s*\(\s*([^)]*)/;
const RE_DOM_QUERY = /\.(querySelector|querySelectorAll|getElementById|getElementsByClassName|getElementsByTagName)\s*\(/;
const RE_DOM_ARG =
  /\.(?:querySelector|querySelectorAll|getElementById|getElementsByClassName|getElementsByTagName)\s*\(\s*([^)]*)/;
/* new Intl.DateTimeFormat only. new Date( is too common and too cheap for this rule. */
const RE_INTL_DTF = /\bnew\s+Intl\.DateTimeFormat\s*\(/;
const RE_INTL_ARG = /\bnew\s+Intl\.DateTimeFormat\s*\(\s*([^)]*)/;
const MSG_JP010 =
  "new Intl.DateTimeFormat in a loop; the bench reused one unchanged formatter. Build it outside only when locale and options stay the same";
const RE_READFILE = /\breadFileSync\s*\(/;
const RE_READFILE_ARG = /\breadFileSync\s*\(\s*([^)]*)/;
const RE_CLOCK = /\b(?:Date\.now|performance\.now)\s*\(/;
const MSG_JP011 =
  "readFileSync in the loop body; the bench reopened one unchanged path. Hoist only when this path stays the same";
const MSG_JP012 =
  "Date.now/performance.now in a tight loop with no await; the bench did not wait. Hoist only when this iteration does not need a fresh time";

/* "jp-map-filter-chain": .map|.filter|.flatMap chained to another — intermediate alloc */
const RE_MAP_FILTER_CHAIN =
  /\.\s*(?:map|filter|flatMap)\s*\([\s\S]*?\)\s*\.\s*(?:map|filter|flatMap)\s*\(/;

function isIdentChar(ch) {
  if (!ch) return false;
  return (
    (ch >= "0" && ch <= "9") ||
    (ch >= "A" && ch <= "Z") ||
    (ch >= "a" && ch <= "z") ||
    ch === "_" ||
    ch === "$"
  );
}

/** Blank ' " ` contents so a binding name inside a literal is not a loop variable. */
function blankStrings(s) {
  const parts = [];
  let q = null;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (q) {
      if (ch === "\\" && q !== "`") {
        parts.push(" ");
        i++;
        if (i < s.length) parts.push(" ");
        continue;
      }
      if (ch === q) q = null;
      parts.push(" ");
      continue;
    }
    if (ch === "'" || ch === '"' || ch === "`") {
      q = ch;
      parts.push(" ");
      continue;
    }
    parts.push(ch);
  }
  return parts.join("");
}

function headerBindings(line) {
  const names = [];
  function add(name) {
    if (name) names.push(name);
  }
  let m = /\bfor\s*(?:await\s*)?\(\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s+(?:of|in)\b/.exec(line);
  if (m) add(m[1]);
  m = /\bfor\s*\(\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=/.exec(line);
  if (m) add(m[1]);
  m = /\bfor\s*\(\s*([A-Za-z_$][\w$]*)\s*=[^;]*;/.exec(line);
  if (m) add(m[1]);
  m = /(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s+(?:of|in)\b/.exec(line);
  if (m) add(m[1]);
  m = /\bfor\s*(?:await\s*)?\(\s*(?:const|let|var)\s*[[{]([^\]}=]{0,120})/.exec(line);
  if (!m) m = /(?:const|let|var)\s*[[{]([^\]}=]{0,120})/.exec(line);
  if (m) {
    const ids = m[1].match(/[A-Za-z_$][\w$]*/g);
    if (ids) {
      let i = 0;
      while (i < ids.length) add(ids[i++]);
    }
  }
  return names;
}

/** True when the call argument names a binding from the enclosing for. */
function argUsesBinding(raw, re, binds) {
  if (!binds.length) return false;
  const m = re.exec(raw);
  if (!m) return false;
  const arg = blankStrings(m[1]);
  for (let b = 0; b < binds.length; b++) {
    const name = binds[b];
    let from = 0;
    while (from < arg.length) {
      const at = arg.indexOf(name, from);
      if (at < 0) break;
      const before = at > 0 ? arg[at - 1] : "";
      const after = arg[at + name.length] || "";
      if (!isIdentChar(before) && !isIdentChar(after)) return true;
      from = at + name.length;
    }
  }
  return false;
}

function isBootstrapPath(filePath) {
  const norm = filePath.replace(/\\/g, "/");
  const base = path.basename(norm);
  return /\/internal\/bootstrap(\/|$)/.test(norm) || /bootstrap/i.test(base);
}

/** util.inspect / debugger pretty-printers — not request hot paths. */
function isInspectPath(filePath) {
  const norm = filePath.replace(/\\/g, "/");
  const base = path.basename(norm);
  return (
    base === "inspect.js" ||
    /\/util\/inspect\.js$/.test(norm) ||
    /\/internal\/debugger\//.test(norm) ||
    /\/internal\/test_runner\//.test(norm)
  );
}


/** Reporters / diff printers / tables — chained map/filter here is formatting, not a request path. */
function isColdFormatterPath(filePath) {
  const norm = filePath.replace(/\\/g, "/");
  if (isInspectPath(filePath)) return true;
  return (
    /\/reporter\//.test(norm) ||
    /\/bench_runner\//.test(norm) ||
    /myers_diff\.js$/.test(norm) ||
    /cli_table\.js$/.test(norm) ||
    /\/assert\//.test(norm)
  );
}

/** Ctors that clearly allocate GC-visible containers/buffers (not domain classes). */
const RE_CLEAR_CTOR =
  /^(Map|Set|WeakMap|WeakSet|Array|Object|Buffer|ArrayBuffer|SharedArrayBuffer|Uint8Array|Int8Array|Uint16Array|Int16Array|Uint32Array|Int32Array|Float32Array|Float64Array|BigUint64Array|BigInt64Array|DataView|Promise|MessageChannel|MessagePort)$/;

function hotNewAlloc(line) {
  if (RE_OBJECT_CREATE.test(line)) return true;
  /* "once-init": x ??= new Map() — not a per-iteration alloc pattern we target */
  if (/\?\?=/.test(line) && /\bnew\s+/.test(line)) return false;
  RE_NEW_CTOR.lastIndex = 0;
  let m;
  while ((m = RE_NEW_CTOR.exec(line))) {
    const before = line.slice(0, m.index);
    if (/\bthrow\s*$/.test(before.trimEnd()) || /\bthrow\s+$/.test(before)) continue;
    if (RE_ERROR_CTOR.test(m[1])) continue;
    /* Node primordials SafeMap/SafeSet — bookkeeping, skip */
    if (/^Safe\w+$/.test(m[1])) continue;
    if (!RE_CLEAR_CTOR.test(m[1])) continue;
    return true;
  }
  return false;
}

/** Build a finding object outside call-site loops so jp-alloc-in-loop does not self-hit. */
function makeFinding(rule, filePath, lineNo, message) {
  return { rule: rule, path: filePath, line: lineNo, message: message };
}

/**
 * Strip comments while tracking multi-line block comments across lines.
 * Returns { code, inBlock } where code has comments blanked.
 */
function stripLineStateful(raw, inBlock) {
  /* Blank a line into parts, then join. */
  const parts = [];
  let i = 0;
  let inLine = false;
  let inStr = null;
  while (i < raw.length) {
    const ch = raw[i];
    const next = raw[i + 1];
    if (inBlock) {
      if (ch === "*" && next === "/") {
        parts.push("  ");
        i += 2;
        inBlock = false;
        continue;
      }
      parts.push(" ");
      i++;
      continue;
    }
    if (inLine) {
      parts.push(" ");
      i++;
      continue;
    }
    if (inStr) {
      if (ch === "\\" && inStr !== "`") {
        parts.push("  ");
        i += 2;
        continue;
      }
      if (inStr === "`" && ch === "$" && next === "{") {
        parts.push(" {");
        i += 2;
        continue;
      }
      if (ch === inStr) {
        inStr = null;
        parts.push(" ");
        i++;
        continue;
      }
      parts.push(ch === "{" || ch === "}" ? ch : " ");
      i++;
      continue;
    }
    if (ch === "/" && next === "*") {
      parts.push("  ");
      i += 2;
      inBlock = true;
      continue;
    }
    if (ch === "/" && next === "/") {
      parts.push("  ");
      i += 2;
      inLine = true;
      continue;
    }
    if (ch === "'" || ch === '"' || ch === "`") {
      inStr = ch;
      parts.push(" ");
      i++;
      continue;
    }
    parts.push(ch);
    i++;
  }
  return { code: parts.join(""), inBlock };
}

function scanFile(filePath) {
  const text = readSource(filePath);
  const lines = text.split(/\r?\n/);
  const findings = [];
  let depth = 0;
  const loopStack = [];
  const loopAwait = [];
  const loopBinds = [];
  const clockIdx = [];
  const clockFindings = [];
  let pendingLoop = false;
  let pendingForAwait = false;
  let pendingBinds = [];
  let inBlock = false;
  const skipJp003 = isBootstrapPath(filePath) || isInspectPath(filePath);
  const skipJp001 = isInspectPath(filePath);
  const skipCold = isColdFormatterPath(filePath);

  function bindsNow() {
    const names = [];
    let i = 0;
    while (i < loopBinds.length) {
      const group = loopBinds[i++];
      let j = 0;
      while (j < group.length) names.push(group[j++]);
    }
    return names;
  }

  function flushClocks(idx) {
    const keepIdx = [];
    const keepFindings = [];
    let p = 0;
    while (p < clockIdx.length) {
      if (clockIdx[p] !== idx) {
        keepIdx.push(clockIdx[p]);
        keepFindings.push(clockFindings[p]);
      } else if (!loopAwait[idx]) {
        findings.push(clockFindings[p]);
      }
      p++;
    }
    clockIdx.length = 0;
    clockFindings.length = 0;
    let k = 0;
    while (k < keepIdx.length) {
      clockIdx.push(keepIdx[k]);
      clockFindings.push(keepFindings[k]);
      k++;
    }
  }

  function clearPending() {
    pendingLoop = false;
    pendingForAwait = false;
    pendingBinds = [];
  }

  for (let i = 0; i < lines.length; i++) {
    const lineNo = i + 1;
    const raw = lines[i];
    const stripped = stripLineStateful(raw, inBlock);
    const line = stripped.code;
    inBlock = stripped.inBlock;
    const wasInLoop = loopStack.length > 0;
    const lineHasAwait = /\bawait\b/.test(line);

    /* Avoid treating /\b(for|while|do)\b/ inside RE_* regex literals as real loops. */
    if (RE_LOOP.test(line) && !/\bconst\s+RE_\w+\s*=/.test(line)) {
      pendingLoop = true;
      pendingForAwait = /\bfor\s+await\b/.test(line) || lineHasAwait;
      pendingBinds = headerBindings(line);
    } else if (pendingLoop) {
      const more = headerBindings(line);
      if (more.length) pendingBinds = pendingBinds.concat(more);
      if (lineHasAwait) pendingForAwait = true;
    }

    if (wasInLoop && lineHasAwait) {
      let a = 0;
      while (a < loopAwait.length) {
        loopAwait[a] = true;
        a++;
      }
    }

    let openedAt = -1;
    for (let c = 0; c < line.length; c++) {
      const ch = line[c];
      if (ch === "{") {
        depth++;
        if (pendingLoop) {
          loopStack.push(depth);
          loopAwait.push(pendingForAwait);
          loopBinds.push(pendingBinds);
          if (openedAt < 0) openedAt = c;
          clearPending();
        }
      } else if (ch === "}") {
        if (loopStack.length && depth === loopStack[loopStack.length - 1]) {
          flushClocks(loopStack.length - 1);
          loopStack.pop();
          loopAwait.pop();
          loopBinds.pop();
        }
        depth = Math.max(0, depth - 1);
        if (pendingLoop) clearPending();
      }
    }

    if (pendingLoop && /\)\s*;/.test(line) && !line.includes("{")) {
      clearPending();
    } else if (pendingLoop && !line.includes("{") && /;/.test(line) && !RE_LOOP.test(line)) {
      clearPending();
    }

    const inLoop = loopStack.length > 0;
    const allocish =
      RE_PUSH_ALLOC.test(line) || RE_ASSIGN_NONEMPTY.test(line) || hotNewAlloc(line);
    if (inLoop && allocish && !skipJp001) {
      findings.push(makeFinding("jp-alloc-in-loop", filePath, lineNo, MSG_JP001));
    }
    if (inLoop && RE_CONSOLE.test(line)) {
      findings.push(makeFinding("jp-console-in-loop", filePath, lineNo, MSG_JP002));
    }
    if (!skipJp003 && RE_DELETE_ARRAY_INDEX.test(line)) {
      findings.push(makeFinding("jp-delete-array-hole", filePath, lineNo, MSG_JP004));
    } else if (!skipJp003 && RE_DELETE_COMPUTED.test(line)) {
      findings.push(makeFinding("jp-delete-shape", filePath, lineNo, MSG_JP003));
    } else if (!skipJp003 && RE_DELETE.test(line)) {
      findings.push(makeFinding("jp-delete-shape", filePath, lineNo, MSG_JP003));
    }
    /* Match the stripped line so a comment cannot carry .filter().map(). */
    if (!skipCold && RE_MAP_FILTER_CHAIN.test(line)) {
      findings.push(makeFinding("jp-map-filter-chain", filePath, lineNo, MSG_JP006));
    }
    const binds = inLoop ? bindsNow() : [];
    if (inLoop && RE_NEW_REGEXP.test(line) && !argUsesBinding(raw, RE_NEW_REGEXP_ARG, binds)) {
      findings.push(makeFinding("jp-regex-ctor-in-loop", filePath, lineNo, MSG_JP007));
    }
    if (inLoop && RE_JSON.test(line) && !argUsesBinding(raw, RE_JSON_ARG, binds)) {
      findings.push(makeFinding("jp-json-in-loop", filePath, lineNo, MSG_JP008));
    }
    if (inLoop && RE_DOM_QUERY.test(line) && !argUsesBinding(raw, RE_DOM_ARG, binds)) {
      findings.push(makeFinding("jp-dom-query-in-loop", filePath, lineNo, MSG_JP009));
    }
    if (inLoop && RE_INTL_DTF.test(line) && !argUsesBinding(raw, RE_INTL_ARG, binds)) {
      findings.push(makeFinding("jp-intl-datetimeformat-in-loop", filePath, lineNo, MSG_JP010));
    }
    let readScope = "";
    if (wasInLoop) readScope = line;
    else if (openedAt >= 0) readScope = line.slice(openedAt + 1);
    if (readScope && RE_READFILE.test(readScope) && !argUsesBinding(raw, RE_READFILE_ARG, binds)) {
      findings.push(makeFinding("jp-readfile-sync-in-loop", filePath, lineNo, MSG_JP011));
    }
    if (inLoop && RE_CLOCK.test(line)) {
      const top = loopAwait.length - 1;
      if (top >= 0 && !loopAwait[top]) {
        clockIdx.push(top);
        clockFindings.push(makeFinding("jp-clock-in-loop", filePath, lineNo, MSG_JP012));
      }
    }
  }
  while (loopStack.length) {
    flushClocks(loopStack.length - 1);
    loopStack.pop();
    loopAwait.pop();
    loopBinds.pop();
  }
  return findings;
}

function shouldSkipDir(name) {
  return (
    name === "node_modules" ||
    name === ".git" ||
    name === "dist" ||
    name === "coverage" ||
    name === "tests" ||
    name === "test" ||
    name === "benchmarks" ||
    name === "demo" ||
    name === "fixtures"
  );
}

/** Codegen / table builders — cold; map/filter chains are OK-idiom. */
function shouldSkipFile(filePath) {
  const base = path.basename(filePath).toLowerCase();
  if (base.startsWith("gen-") || base.startsWith("gen_")) return true;
  if (base.includes("generate")) return true;
  if (base === "diagnosticformatter.ts" || base === "diagnosticformatter.js") return true;
  return false;
}

function scanPath(root) {
  const out = [];
  const st = fs.statSync(root);
  if (st.isFile()) {
    if (EXTS.has(path.extname(root)) && !shouldSkipFile(root)) out.push(...scanFile(root));
    return out;
  }
  const walk = (dir) => {
    const ents = fs.readdirSync(dir, { withFileTypes: true });
    let ei = 0;
    while (ei < ents.length) {
      const ent = ents[ei++];
      if (ent.name.startsWith(".")) continue;
      const p = path.join(dir, ent.name);
      if (ent.isDirectory()) {
        if (!shouldSkipDir(ent.name)) walk(p);
      } else if (EXTS.has(path.extname(ent.name))) {
        if (shouldSkipFile(p)) continue;
        const part = scanFile(p);
        let j = 0;
        while (j < part.length) {
          out.push(part[j]);
          j++;
        }
      }
    }
  };
  walk(root);
  return out;
}

module.exports = { scanPath, scanFile, isBootstrapPath, isInspectPath, isColdFormatterPath, shouldSkipFile, makeFinding };
