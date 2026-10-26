using System.Collections.Generic;
class Bad {
  static List<int> Grow(int n) {
    var list = new List<int>();
    for (int i = 0; i < n; i++) {
      list.Add(i);
    }
    return list;
  }
}
