using System.Collections.Generic;
using System.Linq;

class Good {
  public int Count(List<int> row) {
    var copy = row.ToList();
    int n = 0;
    foreach (var x in copy) {
      if (x > 0) n++;
    }
    return n;
  }
}
