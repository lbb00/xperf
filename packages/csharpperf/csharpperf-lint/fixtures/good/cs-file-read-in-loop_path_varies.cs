static int Good(string[] files) {
  int s = 0;
  for (int i = 0; i < files.Length; i++) {
    var data = File.ReadAllText(files[i]);
    s += data.Length;
  }
  return s;
}
