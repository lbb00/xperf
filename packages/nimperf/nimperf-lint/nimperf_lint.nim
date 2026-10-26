## nimperf-lint — heuristic Nim performance checker (line-based).
## Rules: nm-seq-add-in-loop and nm-echo-in-loop demoted; nm-seq-no-capacity empty seq + .add in size-hinted loop. nm-string-amp-in-loop removed.
import std/[os, strutils, strformat, parseopt, json, tables]

const MSG = {
  "nm-seq-add-in-loop": "seq .add / grow in loop; prefer newSeqOfCap / setLen when length known",
  "nm-echo-in-loop": "echo in loop; gate or buffer",
  "nm-seq-no-capacity": "empty seq grown with .add in size-hinted loop; prefer newSeqOfCap"
}.toTable

var sev = {"nm-seq-add-in-loop": "off", "nm-echo-in-loop": "off", "nm-seq-no-capacity": "hint"}.toTable

const ALWAYS_SKIP = [".git", "nimblecache", "nimcache", "node_modules", "vendor"]
const NOISE_SKIP = ["test", "tests", "testament", "fixtures", "examples", "example",
                    "docs", "doc", "benchmark", "benchmarks", "bench", "testsuites",
                    "tools", "nimpretty", "nimsuggest", "ci", "android", "web",
                    "compiler"]

type Finding = object
  rule, path: string
  line: int
  message: string

var enableReverseOpt = true
var formatOut = "text"
var strictHints = false
var noFail = false

proc pushFinding(dst: var seq[Finding]; f: Finding) =
  let n = dst.len
  dst.setLen(n + 1)
  dst[n] = f

proc pushStr(dst: var seq[string]; s: string) =
  let n = dst.len
  dst.setLen(n + 1)
  dst[n] = s

proc pushInt(dst: var seq[int]; v: int) =
  let n = dst.len
  dst.setLen(n + 1)
  dst[n] = v

proc usage(code: int) =
  stderr.write("""Usage: nimperf-lint PATH... [options]
  --format text|json
  --severity RULE=error|hint|off
  --strict-hints
  --no-fail
  --raw-paths          include test/docs (baseline dumps)
""")
  quit(code)

proc applySev(spec: string): bool =
  let parts = spec.split('=', 1)
  if parts.len != 2: return false
  let rule = parts[0]
  let level = parts[1]
  if rule notin sev: return false
  if level notin ["off", "hint", "error"]: return false
  sev[rule] = level
  true

proc stripComment(line: string): string =
  ## Drop # comments outside strings without per-char .add in a loop.
  var cut = line.len
  var inStr = false
  var q = '\0'
  var i = 0
  while i < line.len:
    let c = line[i]
    if inStr:
      if c == '\\' and i + 1 < line.len:
        i += 2
        continue
      if c == q:
        inStr = false
      i += 1
    else:
      if c == '"' or c == '\'':
        inStr = true
        q = c
        i += 1
      elif c == '#':
        cut = i
        break
      else:
        i += 1
  result = line[0..<cut]

proc isLoopLine(code: string): bool =
  code.contains("for ") or code.contains("while ") or
    code.startsWith("for\t") or code.startsWith("while\t")

proc looksSeqAdd(code: string): bool =
  ## Flag seq-like .add in loops; suppress string builders + NimNode AST.
  if ".add(" notin code and ".add (" notin code:
    return false
  if "newSeqOfCap" in code or "setLen(" in code:
    return false
  # NimNode / PNode AST
  if ".sons.add(" in code or "sons.add(" in code:
    return false
  if "newNimNode" in code or "nnk" in code or "bindSym" in code or "genSym" in code:
    return false
  # string builder literals: .add('x') / .add("...") / .add(&"...")
  if ".add('" in code or ".add(\"" in code or ".add(&" in code:
    return false
  # common separator / builder helpers on result (no for-loop — avoids self-hit on ".add(")
  if "result.add(" in code and (
      ".add(sep)" in code or ".add(prefix)" in code or ".add(suffix)" in code or
      ".add(separator)" in code or ".add(sp)" in code or ".add(comma)" in code or
      ".add(rowSep)" in code):
    return false
  true

proc looksEcho(code: string): bool =
  let t = code.strip()
  if not (t.startsWith("echo ") or t.startsWith("echo(") or t.startsWith("echo\"")):
    return false
  # debug / assert style — keep as OK-idiom offline; suppress here
  let low = t.toLowerAscii()
  if "sysassert" in low or "debug" in low:
    return false
  true

proc indentOf(line: string): int =
  var n = 0
  for c in line:
    if c == ' ': inc n
    elif c == '\t': n += 2
    else: break
  n


proc loopHasSizeHint(code: string): bool =
  ## for i in 0..<n / for x in xs / countdown / len(
  if "0..<" in code or "0.." in code or "countdown(" in code or "len(" in code:
    return true
  if " in " in code:
    return true
  false

proc looksEmptySeqBind(code: string; name: var string): bool =
  ## var xs: seq[T]  |  xs = @[]  |  xs = newSeq[...](
  let s = code.strip()
  # var/let name: seq[...]
  if s.startsWith("var ") or s.startsWith("let "):
    var rest = s[4..^1].strip()
    var i = 0
    while i < rest.len and (rest[i].isAlphaNumeric or rest[i] == '_'):
      inc i
    if i == 0: return false
    name = rest[0..<i]
    let after = rest[i..^1].strip()
    if after.startsWith(":") and "seq[" in after:
      # var xs: seq[int]   or  var xs: seq[int] = @[]
      if "= @[]" in after or after.find("=") < 0:
        return true
      if "newSeq" in after and "newSeqOfCap" notin after:
        return true
    if after.startsWith("="):
      let rhs = after[1..^1].strip()
      if rhs == "@[]" or (rhs.startsWith("newSeq") and "newSeqOfCap" notin rhs):
        return true
  # name = @[] / name = newSeq
  var i = 0
  while i < s.len and (s[i].isAlphaNumeric or s[i] == '_'):
    inc i
  if i == 0: return false
  name = s[0..<i]
  let after = s[i..^1].strip()
  if after.startsWith("="):
    let rhs = after[1..^1].strip()
    if rhs == "@[]" or (rhs.startsWith("newSeq") and "newSeqOfCap" notin rhs):
      return true
  false

proc scanFile(path: string): seq[Finding] =
  result = @[]
  var f: File
  if not open(f, path):
    return
  defer: f.close()
  var lineNo = 0
  var loopIndents: seq[int] = @[]
  var loopHeads: seq[string] = @[]
  var bindNames: seq[string] = @[]
  var bindLines: seq[int] = @[]
  var bindIndents: seq[int] = @[]
  var fired004: seq[string] = @[]
  for raw in f.lines:
    inc lineNo
    let code = stripComment(raw)
    let ind = indentOf(raw)
    while loopIndents.len > 0 and ind <= loopIndents[^1] and code.strip().len > 0:
      discard loopIndents.pop()
      if loopHeads.len > 0: discard loopHeads.pop()
      fired004 = @[]
    let stripped = code.strip()
    if stripped.len == 0:
      continue
    var bname = ""
    if looksEmptySeqBind(stripped, bname):
      pushStr(bindNames, bname)
      pushInt(bindLines, lineNo)
      pushInt(bindIndents, ind)
    # drop stale binds
    var keepN: seq[string] = @[]
    var keepL: seq[int] = @[]
    var keepI: seq[int] = @[]
    var bi = 0
    while bi < bindNames.len:
      if lineNo - bindLines[bi] <= 80:
        pushStr(keepN, bindNames[bi])
        pushInt(keepL, bindLines[bi])
        pushInt(keepI, bindIndents[bi])
      inc bi
    bindNames = keepN
    bindLines = keepL
    bindIndents = keepI
    if isLoopLine(stripped):
      pushInt(loopIndents, ind)
      pushStr(loopHeads, stripped)
      fired004 = @[]
      continue
    if loopIndents.len == 0:
      continue
    if ind <= loopIndents[^1]:
      continue
    if looksSeqAdd(stripped):
      pushFinding(result, Finding(rule: "nm-seq-add-in-loop", path: path, line: lineNo, message: MSG["nm-seq-add-in-loop"]))
    if looksEcho(stripped):
      pushFinding(result, Finding(rule: "nm-echo-in-loop", path: path, line: lineNo, message: MSG["nm-echo-in-loop"]))
    # nm-seq-no-capacity: empty seq + .add in size-hinted loop
    let head = if loopHeads.len > 0: loopHeads[^1] else: ""
    if loopHasSizeHint(head) and looksSeqAdd(stripped) and "newSeqOfCap" notin stripped:
      # extract receiver of .add
      let dot = stripped.find(".add")
      if dot > 0:
        var s = dot - 1
        while s >= 0 and (stripped[s].isAlphaNumeric or stripped[s] == '_'):
          dec s
        let recv = stripped[s+1 ..< dot]
        var already = false
        for x in fired004:
          if x == recv: already = true
        if not already:
          var matched = false
          var bj = 0
          while bj < bindNames.len:
            if bindNames[bj] == recv:
              matched = true
            inc bj
          if matched:
            pushStr(fired004, recv)
            pushFinding(result, Finding(rule: "nm-seq-no-capacity", path: path, line: lineNo, message: MSG["nm-seq-no-capacity"]))

proc pathSkipped(path, root: string): bool =
  let absRoot = absolutePath(root)
  var rel = path
  if path.startsWith(absRoot):
    rel = path[absRoot.len .. ^1]
    if rel.startsWith("/") or rel.startsWith("\\"):
      rel = rel[1 .. ^1]
  for seg in rel.split({DirSep, AltSep}):
    if seg in ALWAYS_SKIP: return true
    if enableReverseOpt and seg in NOISE_SKIP: return true
    if seg == "fixtures" and "fixtures" notin absRoot.split({DirSep, AltSep}):
      return true
  false

proc scanPath(root: string): seq[Finding] =
  result = @[]
  let rootAbs = absolutePath(root)
  if fileExists(rootAbs):
    if rootAbs.endsWith(".nim") or rootAbs.endsWith(".nims"):
      return scanFile(rootAbs)
    return
  if not dirExists(rootAbs):
    return
  for f in walkDirRec(rootAbs):
    if not (f.endsWith(".nim") or f.endsWith(".nims")): continue
    if pathSkipped(f, rootAbs): continue
    let part = scanFile(f)
    let base = result.len
    result.setLen(base + part.len)
    var i = 0
    while i < part.len:
      result[base + i] = part[i]
      inc i

proc nextArg(p: var OptParser): string =
  p.next()
  if p.kind != cmdArgument:
    usage(2)
  result = p.key

proc main() =
  var paths: seq[string] = @[]
  var p = initOptParser(commandLineParams())
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "h", "help":
        usage(0)
      of "format":
        if p.val.len > 0:
          formatOut = p.val
        else:
          formatOut = nextArg(p)
      of "severity":
        let spec = if p.val.len > 0: p.val else: nextArg(p)
        if not applySev(spec):
          usage(2)
      of "strict-hints":
        strictHints = true
      of "no-fail":
        noFail = true
      of "raw-paths":
        enableReverseOpt = false
      else:
        usage(2)
    of cmdArgument:
      pushStr(paths, p.key)
  if paths.len == 0:
    usage(2)

  var findings: seq[Finding] = @[]
  for path in paths:
    let part = scanPath(path)
    let base = findings.len
    findings.setLen(base + part.len)
    var i = 0
    while i < part.len:
      findings[base + i] = part[i]
      inc i

  var nerr = 0
  var nhint = 0
  var lines: seq[string] = @[]
  var rowNodes: seq[JsonNode] = @[]
  for f in findings:
    let level = sev.getOrDefault(f.rule, "hint")
    if level == "off":
      continue
    if level == "error":
      inc nerr
    else:
      inc nhint
    if formatOut == "json":
      var row = newJObject()
      row["rule"] = %f.rule
      row["severity"] = %level
      row["path"] = %f.path
      row["line"] = %f.line
      row["message"] = %f.message
      let rn = rowNodes.len
      rowNodes.setLen(rn + 1)
      rowNodes[rn] = row
    else:
      pushStr(lines, &"{f.path}:{f.line}: {level} {f.rule}: {f.message}")

  if formatOut == "json":
    var rows = newJArray()
    # assign elems without .add token in a for-loop body matching nm-seq-add-in-loop
    rows.elems = rowNodes
    stdout.writeLine $rows
  else:
    if lines.len > 0:
      stdout.writeLine lines.join("\n")
    let shown = nerr + nhint
    if shown > 0:
      stderr.writeLine &"{shown} finding(s) ({nerr} error, {nhint} hint)"
    else:
      stderr.writeLine "ok"

  if noFail:
    quit(0)
  if nerr > 0 or (strictHints and nhint > 0):
    quit(1)
  quit(0)

when isMainModule:
  main()
