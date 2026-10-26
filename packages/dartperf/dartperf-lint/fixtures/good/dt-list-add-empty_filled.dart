List<int> good(int n) {
  final v = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    v[i] = i;
  }
  return v;
}
