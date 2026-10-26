using System.Collections.Generic;
class Good {
  static List<int> Grow(int n) {
    var list = new List<int>(n);
    for (int i = 0; i < n; i++) {
      list.Add(i);
    }
    return list;
  }
}
