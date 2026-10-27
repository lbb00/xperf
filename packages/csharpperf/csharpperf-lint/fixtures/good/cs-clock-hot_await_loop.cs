static async Task Good(int n) {
  for (int i = 0; i < n; i++) {
    var s = Stopwatch.GetTimestamp();
    await Task.Delay(1);
    s = s;
  }
}
