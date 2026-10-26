using System;
using System.Text;
class Good {
  static void Dump(int n) {
    var sb = new StringBuilder();
    for (int i = 0; i < n; i++) {
      sb.Append(i).Append('\n');
    }
    Console.Write(sb.ToString());
  }
}
