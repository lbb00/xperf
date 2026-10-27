class Good {
  public string[] Labels(int n) {
    var label = string.Format("{0}", n);
    var xs = new string[n];
    for (int i = 0; i < n; i++) {
      xs[i] = label;
    }
    return xs;
  }
}
