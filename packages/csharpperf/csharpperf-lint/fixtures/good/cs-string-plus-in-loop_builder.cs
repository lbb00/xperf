using System.Text;
class Good {
  static string Cat(string[] parts) {
    var sb = new StringBuilder();
    foreach (var p in parts) {
      sb.Append(p);
    }
    return sb.ToString();
  }
}
