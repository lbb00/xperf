static int Bad(object s, int n) {
  int acc = 0;
  for (int i = 0; i < n; i++) {
    var f = typeof(S).GetField("A");
    acc = (int)f.GetValue(s);
  }
  return acc;
}
