static int Good(int n) {
  var re = new Regex("id");
  int s = 0;
  for (int i = 0; i < n; i++) {
    if (re.IsMatch("id-2026")) s = 1;
  }
  return s;
}
