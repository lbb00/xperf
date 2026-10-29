static int Bad(int n) {
  int s = 0;
  for (int i = 0; i < n; i++) {
    s = (int)Stopwatch.GetTimestamp();
  }
  return s;
}
