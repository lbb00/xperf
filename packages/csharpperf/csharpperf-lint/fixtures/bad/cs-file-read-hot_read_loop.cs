static int Bad(string path, int n) {
  int s = 0;
  for (int i = 0; i < n; i++) {
    var data = File.ReadAllText(path);
    s = data.Length;
  }
  return s;
}
