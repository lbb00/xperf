int good(int n) {
  var s = 0;
  for (var i = 0; i < n; i++) {
    s += i;
  }
  print(s);
  return s;
}
