using System.Text.RegularExpressions;

static class Good
{
  static readonly Regex Pattern = new("^[a-z]+$", RegexOptions.Compiled);

  static int CountMatches(string[] names)
  {
    int n = 0;
    foreach (var name in names)
    {
      if (Pattern.IsMatch(name))
        n++;
    }
    return n;
  }
}
