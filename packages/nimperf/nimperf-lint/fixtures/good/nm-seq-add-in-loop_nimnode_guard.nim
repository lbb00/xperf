proc fakeAst(n: int) =
  for i in 0..<n:
    discard "x".newNimNode.add(i)
