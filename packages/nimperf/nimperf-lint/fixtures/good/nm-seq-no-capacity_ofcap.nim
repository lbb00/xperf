proc collect(items: seq[int]): seq[int] =
  var out = newSeqOfCap[int](items.len)
  for x in items:
    out.add(x)
  result = out
