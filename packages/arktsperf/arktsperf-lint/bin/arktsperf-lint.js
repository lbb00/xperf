#!/usr/bin/env node
"use strict";

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

function defaultSev() {
  return { "at-alloc-in-loop": SEV_OFF, "at-console-in-loop": SEV_OFF, "at-includes-in-loop": SEV_HINT, "at-json-in-loop": SEV_HINT }; // redesign: at-includes-in-loop/at-json-in-loop
}

/** Build outside call-site loops so at-alloc-in-loop does not self-hit .push({ */
function rowFromFinding(f, sev) {
  const row = Object.create(null);
  row.rule = f.rule;
  row.severity = sevName(sev);
  row.path = f.path;
  row.line = f.line;
  row.message = f.message;
  return row;
}

function usage(code) {
  console.error(
    "Usage: arktsperf-lint PATH... [options]\n" +
      "  --format text|json\n" +
      "  --severity RULE=error|hint|off\n" +
      "  --strict-hints\n" +
      "  --no-fail"
  );
  process.exit(code);
}

function main(argv) {
  const args = argv.slice(2);
  if (!args.length) usage(2);

  const rs = defaultSev();
  let format = "text";
  let strictHints = false;
  let noFail = false;
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
      const parts = spec.split("=");
      if (parts.length < 2) usage(2);
      const rule = parts[0];
            const s = parseSev(parts.slice(1).join("="));
      if (!Object.prototype.hasOwnProperty.call(rs, rule) || s < 0) usage(2);
      rs[rule] = s;
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
    if (a.startsWith("-")) usage(2);
    paths.push(a);
  }
  if (!paths.length) usage(2);

  let findings = [];
  for (let p = 0; p < paths.length; p++) {
    findings = findings.concat(scanPath(paths[p]));
  }

  let nerr = 0;
  let nhint = 0;
  const lines = [];
  const rows = [];
  for (let i = 0; i < findings.length; i++) {
    const f = findings[i];
    const s = Object.prototype.hasOwnProperty.call(rs, f.rule) ? rs[f.rule] : SEV_HINT;
    if (s === SEV_OFF) continue;
    if (s === SEV_ERROR) nerr++;
    else nhint++;
    if (format === "json") {
      rows.push(rowFromFinding(f, s));
    } else {
      lines.push(f.path + ":" + f.line + ": " + sevName(s) + " " + f.rule + ": " + f.message);
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

main(process.argv);
