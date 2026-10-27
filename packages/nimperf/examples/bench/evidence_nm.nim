import std/algorithm
import std/monotimes
import std/os
import std/strutils
import std/times
import std/json

const rounds = 9
const warm = 3

proc median(xs: seq[float]): float =
  var a = xs
  a.sort()
  let n = a.len
  let m = n div 2
  if n mod 2 == 1: a[m] else: 0.5 * (a[m - 1] + a[m])

proc timeMany(fn: proc(): int): float =
  for i in 0..<warm:
    discard fn()
  var samples = newSeq[float](rounds)
  var sink = 0
  for r in 0..<rounds:
    let t0 = getMonoTime()
    sink += fn()
    let us = (getMonoTime() - t0).inMicroseconds.float
    samples[r] = us / 1000.0
  if sink == 0x7fffffff:
    quit(2)
  median(samples)

proc emit(dir, rule: string, cases: seq[tuple[name, role: string, ms: float, ops: int]]) =
  let ts = now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  var lastAfter = 1.0
  var lines = newSeq[string]()
  for c in cases:
    if c.role == "after":
      lastAfter = c.ms
    let ratio = c.ms / lastAfter
    let obj = %*{
      "rule": rule,
      "case": c.name,
      "role": c.role,
      "nim": NimVersion,
      "median_ms": c.ms,
      "ops": c.ops,
      "ratio": ratio,
      "ts": ts,
    }
    lines.add($obj)
    echo "  ", c.role, " ", c.name, " ", c.ms, " ratio=", ratio
  writeFile(dir / (rule & ".jsonl"), lines.join("\n") & "\n")
  echo "wrote ", dir / (rule & ".jsonl")

proc main() =
  let dir = getEnv("EVIDENCE_DIR", "../../evidence")
  echo "nim ", NimVersion
  let nSeq = 200_000
  let beforeAdd = timeMany(proc(): int =
    var xs: seq[int]
    for i in 0..<nSeq:
      xs.add(i)
    xs.len)
  let afterIndex = timeMany(proc(): int =
    var xs = newSeq[int](nSeq)
    for i in 0..<nSeq:
      xs[i] = i
    xs.len)
  emit(dir, "nm-seq-add-hot", @[
    ("index_assign", "after", afterIndex, nSeq),
    ("seq_add", "before", beforeAdd, nSeq),
  ])

  let beforeCap = timeMany(proc(): int =
    var buf: seq[int] = @[]
    for i in 0..<nSeq:
      buf.add(i)
    buf.len)
  let afterCap = timeMany(proc(): int =
    var buf = newSeqOfCap[int](nSeq)
    for i in 0..<nSeq:
      buf.add(i)
    buf.len)
  emit(dir, "nm-seq-no-capacity", @[
    ("newSeqOfCap", "after", afterCap, nSeq),
    ("empty_add", "before", beforeCap, nSeq),
  ])

  let nEcho = 10_000
  let oldOut = stdout
  stdout = open("/dev/null", fmWrite)
  let beforeEcho = timeMany(proc(): int =
    var s = 0
    for i in 0..<nEcho:
      echo i
      s += i
    s)
  let afterEcho = timeMany(proc(): int =
    var s = 0
    for i in 0..<nEcho:
      s += i
    echo s
    s)
  stdout.close()
  stdout = oldOut
  emit(dir, "nm-echo-hot", @[
    ("echo_once", "after", afterEcho, nEcho),
    ("echo_in_loop", "before", beforeEcho, nEcho),
  ])

when isMainModule:
  main()
