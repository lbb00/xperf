proc concatBad() =
  var s = ""
  for i in 0..<100:
    s &= $i  # nm-string-amp-in-loop
