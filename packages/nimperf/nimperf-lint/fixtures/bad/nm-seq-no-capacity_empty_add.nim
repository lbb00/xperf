proc collect(items: seq[int]): seq[int] =
  var out: seq[int] = @[]
  for x in items:
    out.add(x)
  result = out
