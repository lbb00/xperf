class Bad {
  public string[] Labels(int n) {
    var xs = new string[n];
    for (int i = 0; i < n; i++) {
      xs[i] = string.Format("{0}", i);
    }
    return xs;
  }
}
