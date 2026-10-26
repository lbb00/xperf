import std/strutils
proc build(parts: seq[string]): string =
  parts.join("")
