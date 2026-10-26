proc once() =
  var s = ""
  s &= "hello"
  s = s & " world"
  discard s
