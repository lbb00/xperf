proc better(n: int): seq[int] =
  result = newSeq[int](n)
  for i in 0..<n:
    result[i] = i
