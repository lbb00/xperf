proc concatAssign() =
  var s = ""
  for i in 0..<50:
    s = s & $i  # nm-string-amp-in-loop
