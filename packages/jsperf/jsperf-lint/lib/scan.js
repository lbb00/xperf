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

/* Full-tree DOM walk — not the same as caching one selector node. */
const RE_QUERY_ALL_STAR = /\.querySelectorAll\s*\(\s*(['"`])\*\1\s*\)/;
const MSG_QUERY_ALL_STAR =
  "querySelectorAll('*') walks the whole subtree; narrow the selector, use a TreeWalker, or diff mutations — do not cache that NodeList as if it were one node";

/* Repeated executeJavaScript of a built script inside a timer. */
const RE_TIMER = /\b(?:setInterval|setTimeout)\s*\(/;
const RE_EXECJS = /\b(?:executeJavaScript|evaluateHandle)\s*\(/;
const RE_EVALUATE = /\.evaluate\s*\(/;
const MSG_EXECJS_TIMER =
  "executeJavaScript/evaluate of a built script inside setInterval/setTimeout; cache the script string or install once and use a short drain";

/* Per-event deep clone of the handler payload. */
const RE_STRUCTURED_CLONE = /\bstructuredClone\s*\(\s*([^)]*)/;
const RE_JSON_ROUNDTRIP = /JSON\.parse\s*\(\s*JSON\.stringify\s*\(\s*([^)]*)/;
const RE_EVENTISH_ARG =
  /^(?:e|ev|evt|event|payload|msg|message|data|body|detail|req|request|res|response)(?:\.[A-Za-z_$][\w$]*)*$/;
const MSG_CLONE_PER_EVENT =
  "structuredClone / JSON.parse(JSON.stringify(...)) on what looks like the current event payload; reuse fields or clone only what you keep";

const EXEC_CALLEES = /\b(?:executeJavaScript|evaluateHandle)\b|\.evaluate\b/;

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
    /listoffigures_diff\.js$/.test(norm) ||
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

/** True when text before a `{` looks like a nested function/arrow opening. */
function beforeLooksLikeNestedFn(before) {
  const t = before.trimEnd();
  if (/=>\s*$/.test(t)) return true;
  if (/\bfunction\b[\s\S]*$/.test(t) && !/\bfunction\b[\s\S]*\{/.test(t)) return true;
  return false;
}

function eventishArg(raw) {
  const arg = blankStrings(raw).trim().replace(/,\s*$/, "").trim();
  if (!arg || arg.length > 80) return false;
  return RE_EVENTISH_ARG.test(arg);
}

function isStarDomArg(raw) {
  const m = RE_DOM_ARG.exec(raw);
  if (!m) return false;
  const arg = m[1].trim();
  return /^(['"`])\*\1$/.test(arg);
}

/**
 * Pull JS from executeJavaScript / evaluate / evaluateHandle string or template args
 * so inner hot paths are visible to the scanner.
 */
function extractEmbeddedScripts(text) {
  const out = [];
  const re = /\b(?:executeJavaScript|evaluateHandle)\s*\(|\.evaluate\s*\(/g;
  let m;
  while ((m = re.exec(text))) {
    let i = m.index + m[0].length;
    while (i < text.length && (text[i] === " " || text[i] === "\t" || text[i] === "\n" || text[i] === "\r")) i++;
    if (i >= text.length) continue;
    const q = text[i];
    if (q !== "`" && q !== "'" && q !== '"') continue;
    i++;
    const start = i;
    let content = "";
    if (q === "`") {
      let depth = 0;
      while (i < text.length) {
        const ch = text[i];
        if (ch === "\\" && i + 1 < text.length) {
          content += text[i + 1];
          i += 2;
          continue;
        }
        if (ch === "`" && depth === 0) break;
        if (ch === "$" && text[i + 1] === "{") {
          depth++;
          content += " ";
          i += 2;
          continue;
        }
        if (ch === "{" && depth > 0) {
          depth++;
          content += "{";
          i++;
          continue;
        }
        if (ch === "}" && depth > 0) {
          depth--;
          content += depth === 0 ? " " : "}";
          i++;
          continue;
        }
        content += ch;
        i++;
      }
    } else {
      while (i < text.length) {
        const ch = text[i];
        if (ch === "\\" && i + 1 < text.length) {
          content += text[i + 1];
          i += 2;
          continue;
        }
        if (ch === q) break;
        content += ch;
        i++;
      }
    }
    if (content.length < 8) continue;
    const lineBase = text.slice(0, start).split(/\r?\n/).length;
    out.push({ content: content, lineBase: lineBase, outerIndex: m.index });
  }
  return out;
}

function execArgLooksBuilt(rawSlice) {
  if (/`/.test(rawSlice) && rawSlice.length > 60) return true;
  if (/\+/.test(rawSlice) && /['"`]/.test(rawSlice)) return true;
  if (/['"][^'"]{40,}/.test(rawSlice)) return true;
  return false;
}

function scanSource(filePath, text, lineBase) {
  const lines = text.split(/\r?\n/);
  const findings = [];
  let depth = 0;
  const loopStack = [];
  const loopAwait = [];
  const loopBinds = [];
  const clockIdx = [];
  const clockFindings = [];
  const nestFnStack = [];
  const timerStack = [];
  const observerStack = [];
  let pendingLoop = false;
  let pendingForAwait = false;
  let pendingBinds = [];
  let pendingNestedFn = false;
  let pendingTimer = false;
  let pendingObserver = false;
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

  function inNestedFn() {
    return nestFnStack.length > 0;
  }

  function inTimerOrObserver() {
    return timerStack.length > 0 || observerStack.length > 0;
  }

  for (let i = 0; i < lines.length; i++) {
    const lineNo = lineBase + i;
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

    if (RE_TIMER.test(line)) pendingTimer = true;
    if (/\bMutationObserver\b/.test(line)) pendingObserver = true;
    if (
      (wasInLoop || pendingLoop || loopStack.length > 0) &&
      (/\bfunction\b/.test(line) || /=>\s*$/.test(line.trimEnd()) || /=>\s*\{/.test(line))
    ) {
      pendingNestedFn = true;
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
        const before = line.slice(0, c);
        if (pendingLoop) {
          loopStack.push(depth);
          loopAwait.push(pendingForAwait);
          loopBinds.push(pendingBinds);
          if (openedAt < 0) openedAt = c;
          clearPending();
          /* The loop's own "{" is not a nested function body. */
          if (!beforeLooksLikeNestedFn(before)) pendingNestedFn = false;
        } else if (pendingNestedFn || beforeLooksLikeNestedFn(before)) {
          if (loopStack.length > 0) {
            nestFnStack.push(depth);
          }
          pendingNestedFn = false;
        }
        if (pendingTimer) {
          timerStack.push(depth);
          pendingTimer = false;
        }
        if (pendingObserver) {
          observerStack.push(depth);
          pendingObserver = false;
        }
      } else if (ch === "}") {
        if (nestFnStack.length && depth === nestFnStack[nestFnStack.length - 1]) {
          nestFnStack.pop();
        }
        if (timerStack.length && depth === timerStack[timerStack.length - 1]) {
          timerStack.pop();
        }
        if (observerStack.length && depth === observerStack[observerStack.length - 1]) {
          observerStack.pop();
        }
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
    if (pendingTimer && /\)\s*;/.test(line) && !line.includes("{")) pendingTimer = false;
    if (pendingObserver && /\)\s*;/.test(line) && !line.includes("{")) pendingObserver = false;
    if (pendingNestedFn && /=>\s*[^/{]*;/.test(line) && !line.includes("{")) pendingNestedFn = false;

    /*
     * Loop-body smells only look at text that runs each iteration.
     * Header text on the same line as `for (...) {` (before the opening brace) is not the body.
     * Nested function/arrow bodies defined inside a loop are skipped — they run later, not per iteration.
     */
    const smellLine = wasInLoop ? line : openedAt >= 0 ? line.slice(openedAt + 1) : "";
    const inLoopBody = smellLine.length > 0 && (wasInLoop || openedAt >= 0) && !inNestedFn();
    const binds = inLoopBody ? bindsNow() : [];

    const allocish =
      RE_PUSH_ALLOC.test(smellLine) || RE_ASSIGN_NONEMPTY.test(smellLine) || hotNewAlloc(smellLine);
    if (inLoopBody && allocish && !skipJp001) {
      findings.push(makeFinding("jp-alloc-in-loop", filePath, lineNo, MSG_JP001));
    }
    if (inLoopBody && RE_CONSOLE.test(smellLine)) {
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
    if (inLoopBody && RE_NEW_REGEXP.test(smellLine) && !argUsesBinding(raw, RE_NEW_REGEXP_ARG, binds)) {
      findings.push(makeFinding("jp-regex-ctor-in-loop", filePath, lineNo, MSG_JP007));
    }
    if (inLoopBody && RE_JSON.test(smellLine) && !argUsesBinding(raw, RE_JSON_ARG, binds)) {
      /* JSON.parse(JSON.stringify(eventish)) is owned by jp-clone-per-event. */
      if (!RE_JSON_ROUNDTRIP.test(raw)) {
        findings.push(makeFinding("jp-json-in-loop", filePath, lineNo, MSG_JP008));
      }
    }
    if (inLoopBody && RE_DOM_QUERY.test(smellLine) && !argUsesBinding(raw, RE_DOM_ARG, binds)) {
      if (!isStarDomArg(raw) && !RE_QUERY_ALL_STAR.test(smellLine)) {
        findings.push(makeFinding("jp-dom-query-in-loop", filePath, lineNo, MSG_JP009));
      }
    }
    if (inLoopBody && RE_INTL_DTF.test(smellLine) && !argUsesBinding(raw, RE_INTL_ARG, binds)) {
      findings.push(makeFinding("jp-intl-datetimeformat-in-loop", filePath, lineNo, MSG_JP010));
    }
    if (inLoopBody && RE_READFILE.test(smellLine) && !argUsesBinding(raw, RE_READFILE_ARG, binds)) {
      findings.push(makeFinding("jp-readfile-sync-in-loop", filePath, lineNo, MSG_JP011));
    }
    if (inLoopBody && RE_CLOCK.test(smellLine)) {
      const top = loopAwait.length - 1;
      if (top >= 0 && !loopAwait[top]) {
        clockIdx.push(top);
        clockFindings.push(makeFinding("jp-clock-in-loop", filePath, lineNo, MSG_JP012));
      }
    }

    /* jp-query-all-star: match on raw — stripLineStateful blanks string contents. */
    if (RE_QUERY_ALL_STAR.test(raw)) {
      findings.push(makeFinding("jp-query-all-star", filePath, lineNo, MSG_QUERY_ALL_STAR));
    }

    /* jp-execjs-in-timer: built script re-sent from a timer callback. */
    if (timerStack.length > 0 || pendingTimer) {
      if (RE_EXECJS.test(raw) || RE_EVALUATE.test(raw) || RE_EXECJS.test(line) || RE_EVALUATE.test(line)) {
        if (execArgLooksBuilt(raw) || execArgLooksBuilt(line) || /`/.test(raw)) {
          findings.push(makeFinding("jp-execjs-in-timer", filePath, lineNo, MSG_EXECJS_TIMER));
        }
      }
    }

    /* jp-clone-per-event: deep-clone of event-like payload. */
    let cloneHit = false;
    const sc = RE_STRUCTURED_CLONE.exec(raw);
    if (sc && eventishArg(sc[1])) cloneHit = true;
    const jr = RE_JSON_ROUNDTRIP.exec(raw);
    if (jr && eventishArg(jr[1])) cloneHit = true;
    if (cloneHit) {
      findings.push(makeFinding("jp-clone-per-event", filePath, lineNo, MSG_CLONE_PER_EVENT));
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

function dedupeFindings(findings) {
  const seen = Object.create(null);
  const out = [];
  let i = 0;
  while (i < findings.length) {
    const f = findings[i++];
    const key = f.rule + "\0" + f.line + "\0" + f.message;
    if (seen[key]) continue;
    seen[key] = 1;
    out.push(f);
  }
  return out;
}

function scanFile(filePath) {
  const text = readSource(filePath);
  const findings = scanSource(filePath, text, 1);
  const embeds = extractEmbeddedScripts(text);
  let ei = 0;
  while (ei < embeds.length) {
    const emb = embeds[ei++];
    const part = scanSource(filePath, emb.content, emb.lineBase);
    let j = 0;
    while (j < part.length) {
      findings.push(part[j]);
      j++;
    }
    /* Timer wrapping the executeJavaScript call itself (outer call site). */
    const before = text.slice(Math.max(0, emb.outerIndex - 200), emb.outerIndex);
    if (/\b(?:setInterval|setTimeout)\s*\(/.test(before) && emb.content.length > 60) {
      findings.push(
        makeFinding("jp-execjs-in-timer", filePath, emb.lineBase, MSG_EXECJS_TIMER)
      );
    }
  }
  return dedupeFindings(findings);
}

function shouldSkipDir(name) {
  const lower = name.toLowerCase();
  return (
    name === "node_modules" ||
    name === ".git" ||
    name === "dist" ||
    name === "coverage" ||
    name === "tests" ||
    name === "test" ||
    name === "benchmarks" ||
    name === "demo" ||
    name === "fixtures" ||
    lower === "e2e" ||
    lower === "playwright-report" ||
    lower === "test-results" ||
    name === "__tests__" ||
    name === "__mocks__" ||
    lower === "cypress"
  );
}

/** Codegen / table builders / tests — cold; map/filter chains are OK-idiom. */
function shouldSkipFile(filePath) {
  const base = path.basename(filePath).toLowerCase();
  if (base.startsWith("gen-") || base.startsWith("gen_")) return true;
  if (base.includes("generate")) return true;
  if (base === "diagnosticformatter.ts" || base === "diagnosticformatter.js") return true;
  if (/\.(test|spec)\.(js|mjs|cjs|ts|tsx)$/.test(base)) return true;
  if (/\.e2e\.(js|mjs|cjs|ts|tsx)$/.test(base)) return true;
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

module.exports = {
  scanPath,
  scanFile,
  scanSource,
  extractEmbeddedScripts,
  isBootstrapPath,
  isInspectPath,
  isColdFormatterPath,
  shouldSkipFile,
  shouldSkipDir,
  makeFinding,
};
