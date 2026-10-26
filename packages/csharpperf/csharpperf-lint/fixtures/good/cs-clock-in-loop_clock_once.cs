static int Good(int n) {
  int t = (int)Stopwatch.GetTimestamp();
  int s = 0;
  for (int i = 0; i < n; i++) {
    s = t;
  }
  return s;
}
