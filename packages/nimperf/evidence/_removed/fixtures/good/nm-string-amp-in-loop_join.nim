import std/strutils
proc concatOk(parts: seq[string]) =
  let s = parts.join("")
  discard s
