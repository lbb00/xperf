class Bad {
  static string Cat(string[] parts) {
    string s = "";
    foreach (var p in parts) {
      s += p;
    }
    return s;
  }
}
