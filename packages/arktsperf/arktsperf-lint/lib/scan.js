"use strict";

const fs = require("fs");
const path = require("path");

const EXTS = new Set([".ets", ".ts", ".tsx", ".js", ".mjs", ".cjs"]);

const RE_LOOP = /\b(for|while|do)\b|\.forEach\s*\(|\.map\s*\(/;
const RE_PUSH_OBJ = /\.push\s*\(\s*\{/;
const RE_NEW = /\bnew\s+[A-Za-z_$]/
const RE_OBJ_LIT_ASSIGN = /(const|let|var)\s+\w+\s*=\s*\{\s*[^}]/;
const RE_CONSOLE = /console\.(log|debug|info|warn|error)\s*\(/;
const RE_MEMBER = /\.(indexOf|includes)\s*\(/;
const RE_JSON = /\bJSON\.(parse|stringify)\s*\(/;
const RE_JSON_ARG = /\bJSON\.(?:parse|stringify)\s*\(([^)\n]*)/;
const RE_FOR_HEAD = /\bfor\s*\(([^)]*)\)/;
const RE_ARROW_HEAD = /\.(?:forEach|map)\s*\(\s*(?:async\s+)?(?:function\s*)?\(?\s*([^)=]*)/;

const MSG = {
  "at-alloc-in-loop": "allocation-like pattern in loop; reuse objects/arrays when profiles show pressure",
  "at-console-in-loop": "console.* in loop; gate debug / avoid sync bridge chatter on hot path",
  "at-includes-in-loop": "Array.includes/indexOf in loop → Set; String.indexOf → dense LUT (Map often loses on short haystacks)",
  "at-json-in-loop": "JSON.parse/stringify in a loop; hoist only when this value stays the same",
};

function stripLineStateful(raw, inBlock) {
  let out = "";
  let i = 0;
  let inLine = false;
  let inStr = null;
  while (i < raw.length) {
    const ch = raw[i];
    const next = raw[i + 1];
    if (inBlock) {
      if (ch === "*" && next === "/") {
        out += "  ";
        i += 2;
        inBlock = false;
        continue;
      }
      out += " ";
      i++;
      continue;
    }
    if (inLine) {
      out += " ";
      i++;
      continue;
    }
    if (inStr) {
      if (ch === "\\" && inStr !== "`") {
        out += "  ";
        i += 2;
        continue;
      }
      if (ch === inStr) {
        inStr = null;
        out += " ";
        i++;
        continue;
      }
      out += ch === "{" || ch === "}" ? ch : " ";
      i++;
      continue;
    }
    if (ch === "/" && next === "*") {
      out += "  ";
      i += 2;
      inBlock = true;
      continue;
    }
    if (ch === "/" && next === "/") {
      inLine = true;
      out += "  ";
      i += 2;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === "`") {
      inStr = ch;
      out += " ";
      i++;
      continue;
    }
    out += ch;
    i++;
  }
  return { code: out, inBlock: inBlock };
}

function isBenignNew(code) {
  return /\bnew\s+(Map|Set|Date|Error|BusinessError|Array|RegExp|Promise)\b/.test(code);
}

function makeFinding(rule, filePath, lineNo) {
  return { rule: rule, path: filePath, line: lineNo, message: MSG[rule] };
}


function isIdentChar(c) {
  return c === 95 || (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c === 36;
}

function identIn(s, name) {
  if (!name) return false;
  let from = 0;
  while (from <= s.length - name.length) {
    const i = s.indexOf(name, from);
    if (i < 0) return false;
    const before = i === 0 || !isIdentChar(s.charCodeAt(i - 1));
    const afterAt = i + name.length;
    const after = afterAt >= s.length || !isIdentChar(s.charCodeAt(afterAt));
    if (before && after) return true;
    from = i + 1;
  }
  return false;
}

function identsOf(chunk) {
  const skip = new Set(["const", "let", "var", "of", "in", "async", "function"]);
  const names = [];
  const re = /[A-Za-z_$][\w$]*/g;
  let m;
  while ((m = re.exec(chunk))) {
    if (!skip.has(m[0])) names.push(m[0]);
  }
  return names;
}

function headerNames(code) {
  const names = [];
  const fm = RE_FOR_HEAD.exec(code);
  RE_FOR_HEAD.lastIndex = 0;
  if (fm) {
    let head = fm[1];
    if (/\b(?:of|in)\b/.test(head)) head = head.replace(/\s+(?:of|in)\s+[\s\S]*$/, "");
    else if (head.indexOf(";") >= 0) {
      const init = head.split(";")[0];
      const eq = init.match(/([A-Za-z_$][\w$]*)\s*=/);
      if (eq) names.push(eq[1]);
      head = "";
    }
    if (head) names.push.apply(names, identsOf(head));
  }
  const am = RE_ARROW_HEAD.exec(code);
  RE_ARROW_HEAD.lastIndex = 0;
  if (am && am[1]) names.push.apply(names, identsOf(am[1]));
  return names;
}

function jsonArgUses(code, names) {
  if (!names.length) return false;
  const m = RE_JSON_ARG.exec(code);
  RE_JSON_ARG.lastIndex = 0;
  if (!m) return false;
  return names.some(function (n) { return identIn(m[1], n); });
}

function scanFile(filePath) {

  let text;
  try {
    text = fs.readFileSync(filePath, "utf8");
  } catch (e) {
    return [];
  }
  const lines = text.split(/\r?\n/);
  const findings = [];
  let depth = 0;
  let inLoop = 0;
  let inBlock = false;
  let loopNames = [];
  for (let i = 0; i < lines.length; i++) {
    const st = stripLineStateful(lines[i], inBlock);
    inBlock = st.inBlock;
    const code = st.code;
    const opens = (code.match(/\{/g) || []).length;
    const closes = (code.match(/\}/g) || []).length;
    const loopHere = RE_LOOP.test(code);
    if (loopHere) {
      inLoop = depth + 1;
      loopNames = loopNames.concat(headerNames(code));
    }
    if (inLoop > 0 && depth >= inLoop) {
      if (RE_PUSH_OBJ.test(code) || (RE_NEW.test(code) && !isBenignNew(code)) || RE_OBJ_LIT_ASSIGN.test(code)) {
        findings.push(makeFinding("at-alloc-in-loop", filePath, i + 1));
      }
      if (RE_CONSOLE.test(code)) {
        findings.push(makeFinding("at-console-in-loop", filePath, i + 1));
      }
      if (RE_MEMBER.test(code)) {
        findings.push(makeFinding("at-includes-in-loop", filePath, i + 1));
      }
      if (RE_JSON.test(code) && !jsonArgUses(code, loopNames)) {
        findings.push(makeFinding("at-json-in-loop", filePath, i + 1));
      }
    }
    // includes/indexOf on a forEach/map head stays. JSON on that head runs once
    // or takes the callback parameter, so it is not reported here.
    if (loopHere && RE_MEMBER.test(code)) {
      findings.push(makeFinding("at-includes-in-loop", filePath, i + 1));
    }
    depth += opens - closes;
    if (depth < 0) depth = 0;
    if (inLoop > 0 && depth < inLoop) {
      inLoop = 0;
      loopNames = [];
    }
  }
  // de-dupe same rule+line (forEach head + body double)
  const seen = new Set();
  return findings.filter((f) => {
    const k = f.rule + ":" + f.line;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

function skipDir(name) {
  return (
    name === ".git" ||
    name === "node_modules" ||
    name === "fixtures" ||
    name === "oh_modules" ||
    name === "build" ||
    name === "hvigor" ||
    name === "ohosTest" ||
    name === "test" ||
    name === "tests" ||
    name === "Tests" ||
    name === "docs" ||
    name === "DocsSample" ||
    name === "mock" ||
    name === "__tests__"
  );
}

function skipFile(name) {
  if (name === "hvigor-wrapper.js" || name === "hvigorfile.ts") return true;
  if (name.endsWith(".test.ets") || name.endsWith(".test.ts")) return true;
  return false;
}

function scanPath(root) {
  const st = fs.statSync(root);
  if (st.isFile()) {
    const ext = path.extname(root);
    if (skipFile(path.basename(root))) return [];
    return EXTS.has(ext) ? scanFile(root) : [];
  }
  const out = [];
  function walk(dir) {
    let ents;
    try {
      ents = fs.readdirSync(dir, { withFileTypes: true });
    } catch (e) {
      return;
    }
    for (const ent of ents) {
      if (ent.name.startsWith(".")) continue;
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) {
        if (skipDir(ent.name)) continue;
        walk(full);
      } else if (EXTS.has(path.extname(ent.name))) {
        if (skipFile(ent.name)) continue;
        out.push.apply(out, scanFile(full));
      }
    }
  }
  walk(root);
  return out;
}

module.exports = { scanPath, scanFile, MSG };
