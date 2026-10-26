proc buildCmd(args: seq[string]): string =
  result = "cmd"
  for a in args:
    result.add(' ')
    result.add("x")
