using System.Collections.Generic;

static class Demo {
  public static List<int> Build(int n) {
    var list = new List<int>(n);
    for (int i = 0; i < n; i++) {
      list.Add(i);
    }
    return list;
  }
}
