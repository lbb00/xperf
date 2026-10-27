using System.Text.RegularExpressions;

static class Bad
{
  static int CountMatches(string[] names, string pattern)
  {
    int n = 0;
    foreach (var name in names)
    {
      if (Regex.IsMatch(name, pattern))
        n++;
    }
    return n;
  }
}
