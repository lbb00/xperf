using System.Collections.Generic;
using System.Linq;

class Bad {
  public List<int> Expand(List<int[]> rows) {
    var all = new List<int>();
    foreach (var row in rows) {
      all.AddRange(row.ToList());
    }
    return all;
  }
}
