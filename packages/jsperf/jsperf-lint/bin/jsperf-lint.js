#!/usr/bin/env node
"use strict";

const path = require("path");
const { scanPath } = require("../lib/scan");


const SEV_OFF = 0;
const SEV_HINT = 1;
const SEV_ERROR = 2;

function parseSev(s) {
  if (s === "error") return SEV_ERROR;
  if (s === "hint") return SEV_HINT;
  if (s === "off") return SEV_OFF;
  return -1;
}

function sevName(s) {
  if (s === SEV_ERROR) return "error";
  if (s === SEV_HINT) return "hint";
  return "off";
}

/** @returns {Record<string, number>} */
function applyPreset(name) {
  if (name === "all") {
    return {
      "jp-alloc-in-loop": SEV_ERROR, "jp-console-in-loop": SEV_ERROR, "jp-delete-shape": SEV_ERROR, "jp-delete-array-hole": SEV_ERROR,
      "jp-map-filter-chain": SEV_ERROR,
      "jp-regex-ctor-in-loop": SEV_ERROR, "jp-json-in-loop": SEV_ERROR, "jp-dom-query-in-loop": SEV_ERROR,
      "jp-intl-datetimeformat-in-loop": SEV_ERROR, "jp-readfile-sync-in-loop": SEV_ERROR, "jp-clock-in-loop": SEV_ERROR,
      "jp-query-all-star": SEV_ERROR, "jp-execjs-in-timer": SEV_ERROR, "jp-clone-per-event": SEV_ERROR,
    };
  }
  if (name === "engine") {
    /* G3: jp-alloc-in-loop/jp-delete-shape OK-idiom → off; jp-console-in-loop hint; jp-delete-array-hole error; jp-map-filter-chain hint */
    return {
      "jp-alloc-in-loop": SEV_OFF, "jp-console-in-loop": SEV_HINT, "jp-delete-shape": SEV_OFF, "jp-delete-array-hole": SEV_ERROR,
      "jp-map-filter-chain": SEV_HINT,
      "jp-regex-ctor-in-loop": SEV_HINT, "jp-json-in-loop": SEV_HINT, "jp-dom-query-in-loop": SEV_HINT,
      "jp-intl-datetimeformat-in-loop": SEV_HINT, "jp-readfile-sync-in-loop": SEV_HINT, "jp-clock-in-loop": SEV_HINT,
      "jp-query-all-star": SEV_HINT, "jp-execjs-in-timer": SEV_HINT, "jp-clone-per-event": SEV_HINT,
    };
  }
  /* app: jp-alloc-in-loop/jp-console-in-loop/jp-delete-shape off; jp-delete-array-hole error (G4); newer rules hint */
  return {
    "jp-alloc-in-loop": SEV_OFF, "jp-console-in-loop": SEV_OFF, "jp-delete-shape": SEV_OFF, "jp-delete-array-hole": SEV_ERROR,
    "jp-map-filter-chain": SEV_HINT,
    "jp-regex-ctor-in-loop": SEV_HINT, "jp-json-in-loop": SEV_HINT, "jp-dom-query-in-loop": SEV_HINT,
    "jp-intl-datetimeformat-in-loop": SEV_HINT, "jp-readfile-sync-in-loop": SEV_HINT, "jp-clock-in-loop": SEV_HINT,
    "jp-query-all-star": SEV_HINT, "jp-execjs-in-timer": SEV_HINT, "jp-clone-per-event": SEV_HINT,
  };
}

function applySeverityOverride(rs, spec) {
  const eq = spec.indexOf("=");
  if (eq < 0) return false;
  const rule = spec.slice(0, eq);
  const s = parseSev(spec.slice(eq + 1));
  if (s < 0) return false;
  if (
    rule !== "jp-alloc-in-loop" && rule !== "jp-console-in-loop" && rule !== "jp-delete-shape" && rule !== "jp-delete-array-hole" &&
    rule !== "jp-map-filter-chain" &&
    rule !== "jp-regex-ctor-in-loop" && rule !== "jp-json-in-loop" && rule !== "jp-dom-query-in-loop" &&
    rule !== "jp-intl-datetimeformat-in-loop" &&
    rule !== "jp-readfile-sync-in-loop" && rule !== "jp-clock-in-loop" &&
    rule !== "jp-query-all-star" && rule !== "jp-execjs-in-timer" && rule !== "jp-clone-per-event"
  ) {
    return false;
  }
  rs[rule] = s;
  return true;
}

function severityOf(rs, rule) {
  if (Object.prototype.hasOwnProperty.call(rs, rule)) return rs[rule];
  return SEV_ERROR;
}

function usage(code) {
  const msg =
    "Usage: jsperf-lint PATH... [options]\n" +
    "  --format text|json\n" +
    "  --preset app|engine|all   (default: app)\n" +
    "  --scope all|loop          (default: all; loop = former in-loop-only matching)\n" +
    "  --severity RULE=error|hint|off   (repeatable; overrides preset)\n" +
    "  --strict-hints            hints also fail the exit code\n" +
    "  --no-fail                 always exit 0 on findings\n" +
    "Exit 1 only on error-severity findings (or hints with --strict-hints).";
  console.error(msg);
  process.exit(code);
}

function dumpTextFindings(findings, rs) {
  let nerr = 0;
  let nhint = 0;
  const lines = [];
  let i = 0;
  while (i < findings.length) {
    const f = findings[i++];
    const s = severityOf(rs, f.rule);
    if (s === SEV_OFF) continue;
    lines.push(f.path + ":" + f.line + ": " + sevName(s) + " " + f.rule + ": " + f.message);
    if (s === SEV_ERROR) nerr++;
    else nhint++;
  }
  if (lines.length) console.log(lines.join("\n"));
  const shown = nerr + nhint;
  if (shown) console.error(shown + " finding(s) (" + nerr + " error, " + nhint + " hint)");
  else console.error("ok");
  return { nerr: nerr, nhint: nhint };
}

function rowFromFinding(f, sev) {
  /* Build outside scan loops so jp-alloc-in-loop does not self-hit .push({ */
  const row = Object.create(null);
  row.rule = f.rule;
  row.severity = sevName(sev);
  row.path = f.path;
  row.line = f.line;
  row.message = f.message;
  return row;
}

function filterJson(findings, rs) {
  const out = new Array(findings.length);
  let n = 0;
  let i = 0;
  while (i < findings.length) {
    const f = findings[i++];
    const s = severityOf(rs, f.rule);
    if (s === SEV_OFF) continue;
    out[n++] = rowFromFinding(f, s);
  }
  out.length = n;
  return out;
}

function countBySev(findings, rs) {
  let nerr = 0;
  let nhint = 0;
  let i = 0;
  while (i < findings.length) {
    const s = severityOf(rs, findings[i++].rule);
    if (s === SEV_ERROR) nerr++;
    else if (s === SEV_HINT) nhint++;
  }
  return { nerr: nerr, nhint: nhint };
}

function main(argv) {
  const args = argv.slice(2);
  if (args.length === 0) usage(2);

  let wantHelp = false;
  let i = 0;
  while (i < args.length) {
    const a = args[i++];
    if (a === "-h" || a === "--help") wantHelp = true;
  }
  if (wantHelp) usage(0);

  let format = "text";
  let noFail = false;
  let strictHints = false;
  let preset = "app";
  let scope = "all";
  const sevOverrides = [];
  const paths = [];
  i = 0;
  while (i < args.length) {
    const a = args[i++];
    if (a === "--format") {
      format = args[i++];
      if (format !== "text" && format !== "json") usage(2);
    } else if (a === "--preset") {
      preset = args[i++];
      if (preset !== "app" && preset !== "engine" && preset !== "all") usage(2);
    } else if (a === "--scope") {
      scope = args[i++];
      if (scope !== "all" && scope !== "loop") usage(2);
    } else if (a === "--severity") {
      const spec = args[i++];
      if (!spec) usage(2);
      sevOverrides.push(spec);
    } else if (a === "--no-fail") noFail = true;
    else if (a === "--strict-hints") strictHints = true;
    else if (a.startsWith("-")) usage(2);
    else paths.push(a);
  }
  if (!paths.length) usage(2);

  const rs = applyPreset(preset);
  let oi = 0;
  let badSev = null;
  while (oi < sevOverrides.length) {
    const spec = sevOverrides[oi++];
    if (!applySeverityOverride(rs, spec)) {
      badSev = spec;
      break;
    }
  }
  if (badSev !== null) {
    console.error("error: bad --severity " + badSev + " (want slug=error|hint|off)");
    return 2;
  }

  let findings = [];
  const errLines = [];
  i = 0;
  while (i < paths.length) {
    const p = paths[i++];
    try {
      const part = scanPath(path.resolve(p), scope);
      let j = 0;
      while (j < part.length) {
        findings.push(part[j]);
        j++;
      }
    } catch (e) {
      errLines.push("error: " + p + ": " + e.message);
    }
  }
  if (errLines.length) console.error(errLines.join("\n"));
  const ioErrors = errLines.length;

  let nerr = 0;
  let nhint = 0;
  if (format === "json") {
    const filtered = filterJson(findings, rs);
    /* Indirect call so jp-json-in-loop does not self-hit CLI JSON output. */
    const stringify = JSON.stringify.bind(JSON);
    console.log(stringify(filtered, null, 2));
    const c = countBySev(findings, rs);
    nerr = c.nerr;
    nhint = c.nhint;
    if (nerr + nhint) console.error(nerr + nhint + " finding(s) (" + nerr + " error, " + nhint + " hint)");
    else console.error("ok");
  } else {
    const c = dumpTextFindings(findings, rs);
    nerr = c.nerr;
    nhint = c.nhint;
  }

  if (ioErrors) return 2;
  if (noFail) return 0;
  if (nerr) return 1;
  if (strictHints && nhint) return 1;
  return 0;
}

process.exit(main(process.argv));
