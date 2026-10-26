import std/algorithm
import std/monotimes
import std/strutils
import std/times

const rounds = 9
const warm = 3
const nStr = 20_000

proc median(xs: var seq[float]): float =
  xs.sort()
  let n = xs.len
  let m = n div 2
  if n mod 2 == 1: xs[m] else: 0.5 * (xs[m - 1] + xs[m])

proc timeMany(name: string, fn: proc(): int): float =
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
  let med = median(samples)
  stdout.write(name, " median_ms=", med.formatFloat(ffDecimal, 6))
  for s in samples:
    stdout.write(" ", s.formatFloat(ffDecimal, 3))
  echo ""
  med

proc ampAssign(): int =
  var s = ""
  for i in 0..<nStr:
    s &= $i
  s.len

proc joined(): int =
  var parts = newSeq[string](nStr)
  for i in 0..<nStr:
    parts[i] = $i
  parts.join("").len

when isMainModule:
  echo "nim ", NimVersion
  let after = timeMany("join", joined)
  let before = timeMany("amp_assign", ampAssign)
  echo "nim_ratio=", (before / after).formatFloat(ffDecimal, 6)
  echo "DONE_NM_AMP"
