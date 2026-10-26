static int Good(string path, int n) {
  var data = File.ReadAllText(path);
  int s = 0;
  for (int i = 0; i < n; i++) {
    s = data.Length;
  }
  return s;
}
