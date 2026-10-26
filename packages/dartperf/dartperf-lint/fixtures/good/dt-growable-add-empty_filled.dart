List<int> good(List<int> items) {
  // Fixed-length list; index writes — no empty growable + add
  final out = List<int>.filled(items.length, 0);
  for (var i = 0; i < items.length; i++) {
    out[i] = items[i];
  }
  return out;
}
