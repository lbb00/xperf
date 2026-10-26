String good(int n) {
  final b = StringBuffer();
  for (var i = 0; i < n; i++) {
    b.write(i);
  }
  return b.toString();
}
