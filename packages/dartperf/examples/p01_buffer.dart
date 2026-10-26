String join(int n) {
  final b = StringBuffer();
  for (var i = 0; i < n; i++) {
    b.write(i);
  }
  return b.toString();
}

void main() {
  print(join(8));
}
