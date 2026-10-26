static int Bad(int n) {
  int s = 0;
  for (int i = 0; i < n; i++) {
    var re = new Regex("id");
    if (re.IsMatch("id-2026")) s = 1;
  }
  return s;
}
