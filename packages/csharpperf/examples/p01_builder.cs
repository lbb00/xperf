using System.Text;

static class Demo {
  public static string Join(string[] parts) {
    var sb = new StringBuilder();
    foreach (var p in parts) {
      sb.Append(p);
    }
    return sb.ToString();
  }
}
