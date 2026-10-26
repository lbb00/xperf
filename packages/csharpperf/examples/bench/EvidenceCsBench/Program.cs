using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

static class EvidenceCs
{
  const int Rounds = 9, Warm = 3;
  static double Median(List<double> xs)
  {
    xs.Sort();
    int n = xs.Count, m = n / 2;
    return n % 2 == 1 ? xs[m] : 0.5 * (xs[m - 1] + xs[m]);
  }
  static double TimeMany(Func<int> fn)
  {
    for (int i = 0; i < Warm; i++) fn();
    var samples = new List<double>(Rounds);
    int sink = 0;
    for (int r = 0; r < Rounds; r++)
    {
      var sw = Stopwatch.StartNew();
      sink += fn();
      sw.Stop();
      samples.Add(sw.Elapsed.TotalMilliseconds);
    }
    if (sink == int.MinValue) Environment.Exit(2);
    return Median(samples);
  }
  static void Emit(string dir, string rule, (string Case, string Role, double Ms, int Ops)[] pairs)
  {
    double after = pairs.First(p => p.Role == "after").Ms;
    // For multi-pair, compute ratio vs matching after by order: we emit with explicit ratio field using first after of same "group" — simpler: each before uses nearest preceding after
    var lines = new List<string>();
    string ts = DateTime.UtcNow.ToString("o");
    double lastAfter = 1;
    foreach (var p in pairs)
    {
      if (p.Role == "after") lastAfter = p.Ms;
      double ratio = p.Ms / lastAfter;
      lines.Add($"{{\"rule\":\"{rule}\",\"case\":\"{p.Case}\",\"role\":\"{p.Role}\",\"dotnet\":\"{Environment.Version}\",\"median_ms\":{p.Ms.ToString(System.Globalization.CultureInfo.InvariantCulture)},\"ops\":{p.Ops},\"ratio\":{ratio.ToString(System.Globalization.CultureInfo.InvariantCulture)},\"ts\":\"{ts}\"}}");
      Console.WriteLine($"  {p.Role} {p.Case} {p.Ms:F4} ratio={ratio:F3}");
    }
    var path = Path.Combine(dir, rule + ".jsonl");
    File.WriteAllText(path, string.Join("\n", lines) + "\n");
    Console.WriteLine("wrote " + path);
  }

  static int Main()
  {
    string dir = Environment.GetEnvironmentVariable("EVIDENCE_DIR")
      // `dotnet run` puts BaseDirectory at examples/bench/EvidenceCsBench/bin/<config>/net8.0
      ?? Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "..", "evidence"));
    Directory.CreateDirectory(dir);
    Console.WriteLine("dotnet " + Environment.Version + " out=" + dir);

    // cs-regex-in-loop Regex.IsMatch(pattern) each call vs Compiled
    int n = int.Parse(Environment.GetEnvironmentVariable("CS004_N") ?? "50000");
    var names = new string[n];
    for (int i = 0; i < n; i++) names[i] = (i % 3 == 0) ? "abc" : "X" + i;
    string pattern = "^[a-z]+$";
    var compiled = new Regex(pattern, RegexOptions.Compiled);
    double before4 = TimeMany(() =>
    {
      int c = 0;
      for (int i = 0; i < names.Length; i++)
        if (Regex.IsMatch(names[i], pattern)) c++;
      return c;
    });
    double after4 = TimeMany(() =>
    {
      int c = 0;
      for (int i = 0; i < names.Length; i++)
        if (compiled.IsMatch(names[i])) c++;
      return c;
    });
    Emit(dir, "cs-regex-in-loop", new[] {
      ("compiled_regex", "after", after4, n),
      ("regex_ismatch_loop", "before", before4, n),
    });

    // cs-list-add-no-capacity List.Add without Capacity
    int n1 = int.Parse(Environment.GetEnvironmentVariable("CS001_N") ?? "200000");
    var src = Enumerable.Range(0, n1).ToArray();
    double before1 = TimeMany(() =>
    {
      var list = new List<int>();
      for (int i = 0; i < src.Length; i++) list.Add(src[i]);
      return list.Count;
    });
    double after1 = TimeMany(() =>
    {
      var list = new List<int>(src.Length);
      for (int i = 0; i < src.Length; i++) list.Add(src[i]);
      return list.Count;
    });
    Emit(dir, "cs-list-add-no-capacity", new[] {
      ("list_capacity", "after", after1, n1),
      ("list_add_nocap", "before", before1, n1),
    });

    // cs-string-plus-in-loop string += vs StringBuilder
    int n2 = int.Parse(Environment.GetEnvironmentVariable("CS002_N") ?? "30000");
    double before2 = TimeMany(() =>
    {
      string s = "";
      for (int i = 0; i < n2; i++) s += i.ToString();
      return s.Length;
    });
    double after2 = TimeMany(() =>
    {
      var sb = new StringBuilder();
      for (int i = 0; i < n2; i++) sb.Append(i);
      return sb.Length;
    });
    Emit(dir, "cs-string-plus-in-loop", new[] {
      ("stringbuilder", "after", after2, n2),
      ("string_plus_equals", "before", before2, n2),
    });

    // cs-console-in-loop Console in loop vs once (discard)
    int n3 = int.Parse(Environment.GetEnvironmentVariable("CS003_N") ?? "20000");
    var oldOut = Console.Out;
    Console.SetOut(TextWriter.Null);
    double before3 = TimeMany(() =>
    {
      int s = 0;
      for (int i = 0; i < n3; i++) { Console.WriteLine(i); s += i; }
      return s;
    });
    double after3 = TimeMany(() =>
    {
      int s = 0;
      for (int i = 0; i < n3; i++) s += i;
      Console.WriteLine(s);
      return s;
    });
    Console.SetOut(oldOut);
    Emit(dir, "cs-console-in-loop", new[] {
      ("console_once", "after", after3, n3),
      ("console_in_loop", "before", before3, n3),
    });
    return 0;
  }
}
