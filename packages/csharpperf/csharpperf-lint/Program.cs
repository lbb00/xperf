using System.Text.Json;
using System.Text.RegularExpressions;

namespace CsharpPerfLint;

static class Program
{
  static readonly Dictionary<string, string> DefaultSev = new() {
    ["cs-list-add-no-capacity"] = "off", ["cs-string-plus-hot"] = "off", ["cs-console-hot"] = "off", ["cs-regex-hot"] = "hint", ["cs-linq-materialize-hot"] = "hint", ["cs-format-hot"] = "hint", ["cs-json-hot"] = "hint", ["cs-file-read-hot"] = "hint", ["cs-clock-hot"] = "hint", ["cs-field-by-name-hot"] = "hint"
  };

  // Baseline skips (always): build artifacts only
  static readonly HashSet<string> AlwaysSkip = new(StringComparer.OrdinalIgnoreCase) {
    ".git", "bin", "obj", "packages", ".vs", "TestResults"
  };

  // Reverse-opt path skips (enabled by default after corpus dogfood)
  static readonly HashSet<string> NoiseSkip = new(StringComparer.OrdinalIgnoreCase) {
    "test", "tests", "Testing", "benchmarks", "Benchmarks",
    "samples", "Samples", "fixtures", "perf", "benchmark",
    "tools", "Tool", "build", "Build" // corpus reverse-opt: CLI probes / build scripts
  };

  static bool EnableReverseOpt = true; // path skips + heuristics; --raw-paths disables

  static int Main(string[] args)
  {
    if (args.Length == 0) Usage(2);
    var sev = new Dictionary<string, string>(DefaultSev);
    var format = "text";
    var strictHints = false;
    var noFail = false;
    var paths = new List<string>(args.Length);
    var scope = "all";
    for (int i = 0; i < args.Length; i++) {
      var a = args[i];
      if (a is "-h" or "--help") Usage(0);
      if (a == "--format" && i + 1 < args.Length) { format = args[++i]; continue; }
      if (a.StartsWith("--format=")) { format = a["--format=".Length..]; continue; }
      if (a == "--severity" && i + 1 < args.Length) { ApplySev(sev, args[++i]); continue; }
      if (a.StartsWith("--severity=")) { ApplySev(sev, a["--severity=".Length..]); continue; }
      if (a == "--strict-hints") { strictHints = true; continue; }
      if (a == "--no-fail") { noFail = true; continue; }
      if (a == "--raw-paths") { EnableReverseOpt = false; continue; } // baseline comparison
      if (a == "--scope" && i + 1 < args.Length) { scope = args[++i]; if (scope is not ("all" or "loop")) Usage(2); continue; }
      if (a.StartsWith("--scope=")) { scope = a["--scope=".Length..]; if (scope is not ("all" or "loop")) Usage(2); continue; }
      if (a.StartsWith("-")) Usage(2);
      paths.Add(a);
    }
    if (paths.Count == 0) Usage(2);

    var findings = new List<Finding>(256);
    foreach (var p in paths)
      foreach (var f in ScanPath(p, scope)) findings.Add(f);

    int nerr = 0, nhint = 0;
    var rows = new List<object>(findings.Count);
    var lines = new List<string>(findings.Count);
    foreach (var f in findings) {
      if (!sev.TryGetValue(f.Rule, out var level)) level = "hint";
      if (level == "off") continue;
      if (level == "error") nerr++; else nhint++;
      if (format == "json")
        rows.Add(new { rule = f.Rule, severity = level, path = f.Path, line = f.Line, message = f.Message });
      else
        lines.Add($"{f.Path}:{f.Line}: {level} {f.Rule}: {f.Message}");
    }
    if (format == "json") Console.WriteLine(JsonSerializer.Serialize(rows));
    else {
      if (lines.Count > 0) Console.WriteLine(string.Join("\n", lines));
      var shown = nerr + nhint;
      if (shown > 0) Console.Error.WriteLine($"{shown} finding(s) ({nerr} error, {nhint} hint)");
      else Console.Error.WriteLine("ok");
    }
    if (noFail) return 0;
    return nerr > 0 || (strictHints && nhint > 0) ? 1 : 0;
  }

  static void ApplySev(Dictionary<string, string> sevMap, string spec)
  {
    var eq = spec.IndexOf('=');
    if (eq < 0) Usage(2);
    var rule = spec[..eq];
    var level = spec[(eq + 1)..];
    if (!sevMap.ContainsKey(rule) || level is not ("off" or "hint" or "error")) Usage(2);
    sevMap[rule] = level;
  }

  static void Usage(int code)
  {
    Console.Error.WriteLine("""
Usage: csharpperf-lint PATH... [options]
  --format text|json
  --severity RULE=error|hint|off
  --scope all|loop     (default: all; loop = former in-loop-only)
  --strict-hints
  --no-fail
  --raw-paths          include test/benchmarks (baseline dumps)
""");
    Environment.Exit(code);
  }

  record Finding(string Rule, string Path, int Line, string Message);

  static bool ShouldSkipRel(string[] rel)
  {
    var dirs = rel.Take(rel.Length - 1);
    if (dirs.Any(p => AlwaysSkip.Contains(p))) return true;
    if (!EnableReverseOpt) return false;
    if (dirs.Any(p => NoiseSkip.Contains(p))) return true;
    if (dirs.Any(p =>
          p.EndsWith(".Tests", StringComparison.OrdinalIgnoreCase) ||
          p.EndsWith(".UnitTests", StringComparison.OrdinalIgnoreCase) ||
          p.EndsWith("Tests", StringComparison.OrdinalIgnoreCase) && p.Contains('.')))
      return true;
    return false;
  }

  static IEnumerable<Finding> ScanPath(string root, string scope = "all")
  {
    if (File.Exists(root)) {
      if (root.EndsWith(".cs", StringComparison.OrdinalIgnoreCase)) return ScanFile(root, scope);
      return Array.Empty<Finding>();
    }
    var all = new List<Finding>(128);
    var rootFull = Path.GetFullPath(root).Replace('\\', '/').TrimEnd('/');
    var rootParts = rootFull.Split('/');
    foreach (var file in Directory.EnumerateFiles(root, "*.cs", SearchOption.AllDirectories)) {
      var fileFull = Path.GetFullPath(file).Replace('\\', '/');
      var fileParts = fileFull.Split('/');
      if (fileParts.Length <= rootParts.Length) continue;
      var relCount = fileParts.Length - rootParts.Length;
      var rel = new string[relCount];
      for (var ri = 0; ri < relCount; ri++) rel[ri] = fileParts[rootParts.Length + ri];
      if (ShouldSkipRel(rel)) continue;
      all.AddRange(ScanFile(file, scope));
    }
    return all;
  }

  static List<Finding> ScanFile(string path, string scope = "all")
  {
    var reFor = new Regex(@"\b(for|foreach|while)\b");
    var reAdd = new Regex(@"\.Add\s*\(");
    var reCapacity = new Regex(@"\b(Capacity\s*=|new\s+List\s*<[^>]*>\s*\([^)]+\))");
    var reStrPlus = new Regex(@"\w+\s*\+=\s*");
    var reNumPlus = new Regex(@"\+=\s*\d");
    var reConsole = new Regex(@"\bConsole\.(Write|WriteLine)\s*\(");
    // cs-regex-hot: static Regex.IsMatch/Match/... with a pattern string inside a loop (prefer compiled Regex).
    var reRegexStatic = new Regex(@"\bRegex\.(IsMatch|Match|Matches|Replace|Split)\s*\(");
    var reListDecl = new Regex(@"\bList\s*<");
    var reDictishAdd = new Regex(@"\b(flags|map|dict|set|seen|lookup)\.Add\s*\(", RegexOptions.IgnoreCase);
    var reExceptionsAdd = new Regex(@"\bexceptions\.Add\s*\(");
    var reLinqMaterialize = new Regex(@"\.(ToList|ToArray|ToDictionary|ToHashSet)\s*\(");
    var reStringFormat = new Regex(@"\bstring\.Format\s*\(");
    // Encode/decode calls. Built once per file, outside the line loop. Message text stays generic.
    var reJson = new Regex(@"\b(?:JsonSerializer\.(?:Serialize|Deserialize)|JsonConvert\.(?:SerializeObject|DeserializeObject))(?:\s*<[^()\r\n]*>)?\s*\(");
    var reRegexNew = new Regex(@"\bnew\s+Regex\s*\(");
    var reFileRead = new Regex(@"\bFile\.(ReadAllText|Open|OpenRead|OpenText)\s*\(");
    var reClock = new Regex(@"\bStopwatch\.GetTimestamp\s*\(");
    var reFieldName = new Regex(@"\.(GetField|GetProperty)\s*\(");
    var reAwait = new Regex(@"\bawait\b");
    var reForEachHead = new Regex(@"\bforeach\s*\(([^)]*)\)");
    var reForInit = new Regex(@"\bfor\s*\([^;]*?\b([A-Za-z_]\w*)\s*=");
    var reJsonArg = new Regex(@"\b(?:JsonSerializer\.(?:Serialize|Deserialize)|JsonConvert\.(?:SerializeObject|DeserializeObject))(?:\s*<[^()\r\n]*>)?\s*\(([^)\r\n]*)");
    var reRegexNewArg = new Regex(@"\bnew\s+Regex\s*\(([^)\r\n]*)");
    var reRegexStaticArg = new Regex(@"\bRegex\.(?:IsMatch|Match|Matches|Replace|Split)\s*\(([^)\r\n]*)");
    var reFileArg = new Regex(@"\bFile\.(?:ReadAllText|Open|OpenRead|OpenText)\s*\(([^)\r\n]*)");
    var outList = new List<Finding>(64);
    var lines = File.ReadAllLines(path);
    var scopeMode = scope == "loop" ? "loop" : "all";
    int depth = 0, inLoop = 0;
    var recent = new List<string>(16);
    bool sawCapacity = false;
    bool pendingLoop = false; // for/foreach/while with brace on a following line
    var loopNames = new List<string>();
    var clockHold = new List<Finding>();
    bool loopAwait = false;
    // reverse-opt heuristic: Dump*/Debug* writers
    var baseName = Path.GetFileName(path);
    bool fileLooksDumper = baseName.Contains("Dump", StringComparison.OrdinalIgnoreCase)
      || baseName.Contains("Debug", StringComparison.OrdinalIgnoreCase);
    for (int i = 0; i < lines.Length; i++) {
      var code = BlankStrings(StripLineComment(lines[i]));
      if (recent.Count >= 12) recent.RemoveAt(0);
      recent.Add(code);
      int opens = code.Count(c => c == '{');
      int closes = code.Count(c => c == '}');
      if (reFor.IsMatch(code)) {
        sawCapacity = recent.Any(r => reCapacity.IsMatch(r));
        loopNames.AddRange(ForNames(code, reForEachHead, reForInit));
        if (reAwait.IsMatch(code)) loopAwait = true;
        if (opens > 0) {
          inLoop = depth + 1; // brace on same line
          pendingLoop = false;
        } else {
          pendingLoop = true; // wait for the opening brace
          inLoop = 0;
        }
      } else if (pendingLoop) {
        if (opens > 0) {
          inLoop = depth + 1;
          pendingLoop = false;
        } else if (!string.IsNullOrWhiteSpace(code)) {
          // brace-less single-statement loop body: treat this line as the body then clear
          inLoop = depth; // body at current depth for this line only
          // fall through to finding checks; cleared after depth update below
        }
      }
      var matchHere = scopeMode == "all" || (inLoop > 0 && depth >= inLoop);
      if (matchHere) {
        if (reAdd.IsMatch(code) && !sawCapacity) {
          bool listish = !EnableReverseOpt || recent.Any(r => reListDecl.IsMatch(r) || r.Contains("new List", StringComparison.Ordinal));
          if (EnableReverseOpt) {
            if (reDictishAdd.IsMatch(code))
              listish = false;
            if (reExceptionsAdd.IsMatch(code))
              listish = false;
            var relCs = path.Replace('\\', '/');
            if (relCs.Contains("/Localisation/NumberToWords/", StringComparison.OrdinalIgnoreCase)
                || relCs.Contains("/Localisation/WordsToNumber/", StringComparison.OrdinalIgnoreCase)
                || relCs.Contains("/SourceGenerators/", StringComparison.OrdinalIgnoreCase))
              listish = false;
          }
          if (listish)
            outList.Add(new Finding("cs-list-add-no-capacity", path, i + 1, "List.Add without Capacity / pre-size — cost adds up even off a hot path"));
        }
        if (reCapacity.IsMatch(code)) sawCapacity = true;
        if (reStrPlus.IsMatch(code) && LooksStringPlus(code, reNumPlus)) {
          var relPath = path.Replace('\\', '/');
          bool skipWords = EnableReverseOpt && (
            relPath.Contains("/Localisation/NumberToWords/", StringComparison.OrdinalIgnoreCase)
            || relPath.Contains("/Localisation/WordsToNumber/", StringComparison.OrdinalIgnoreCase)
            || relPath.Contains("/Localisation/DateToOrdinalWords/", StringComparison.OrdinalIgnoreCase));
          if (!skipWords)
            outList.Add(new Finding("cs-string-plus-hot", path, i + 1, "string +=; prefer StringBuilder — cost adds up even off a hot path"));
        }
        if (reConsole.IsMatch(code)) {
          if (EnableReverseOpt && fileLooksDumper) { /* skip */ }
          else if (EnableReverseOpt) {
            var prev = i > 0 ? StripLineComment(lines[i - 1]) : "";
            if (!code.Contains("DEBUG", StringComparison.OrdinalIgnoreCase)
                && !prev.Contains("#if", StringComparison.Ordinal)
                && !prev.Contains("DEBUG", StringComparison.OrdinalIgnoreCase))
              outList.Add(new Finding("cs-console-hot", path, i + 1, "Console.Write*; gate or buffer — cost adds up even off a hot path"));
          } else {
            outList.Add(new Finding("cs-console-hot", path, i + 1, "Console.Write*; gate or buffer — cost adds up even off a hot path"));
          }
        }
        if (reAwait.IsMatch(code)) loopAwait = true;
        if (reRegexNew.IsMatch(code) && !ArgUses(FirstArg(reRegexNewArg, code), loopNames)) {
          outList.Add(new Finding("cs-regex-hot", path, i + 1,
            "Regex constructed; compile outside only when this pattern stays the same — cost adds up even off a hot path"));
        }
        if (reRegexStatic.IsMatch(code) && !ArgUses(NthArg(reRegexStaticArg, code, 1), loopNames)) {
          outList.Add(new Finding("cs-regex-hot", path, i + 1,
            "Regex.IsMatch/Match; compile outside only when this pattern stays the same — cost adds up even off a hot path"));
        }
        if (reFileRead.IsMatch(code) && !ArgUses(FirstArg(reFileArg, code), loopNames)) {
          outList.Add(new Finding("cs-file-read-hot", path, i + 1,
            "file read; read once when the path stays the same — cost adds up even off a hot path"));
        }
        if (reClock.IsMatch(code) && !loopAwait) {
          clockHold.Add(new Finding("cs-clock-hot", path, i + 1,
            "clock sample with no await; hoist only when this iteration does not need a fresh time — cost adds up even off a hot path"));
        }
        if (reFieldName.IsMatch(code)) {
          outList.Add(new Finding("cs-field-by-name-hot", path, i + 1,
            "field lookup by name; use the field directly when the name is fixed — cost adds up even off a hot path"));
        }
        if (reLinqMaterialize.IsMatch(code)) {
          outList.Add(new Finding("cs-linq-materialize-hot", path, i + 1,
            "ToList/ToArray/ToDictionary; materialize once — cost adds up even off a hot path"));
        }
        if (reStringFormat.IsMatch(code)) {
          outList.Add(new Finding("cs-format-hot", path, i + 1,
            "string.Format; format outside or use a builder — cost adds up even off a hot path"));
        }
        if (reJson.IsMatch(code) && !ArgUses(FirstArg(reJsonArg, code), loopNames)) {
          outList.Add(new Finding("cs-json-hot", path, i + 1,
            "JSON encode or decode; hoist only when this value stays the same — cost adds up even off a hot path"));
        }
      }
      depth = depth + opens - closes;
      if (depth < 0) depth = 0;
      if (inLoop > 0 && depth < inLoop) {
        if (!loopAwait) outList.AddRange(clockHold);
        clockHold.Clear();
        loopAwait = false;
        loopNames.Clear();
        inLoop = 0;
      }
      // brace-less body was one shot
      if (pendingLoop && inLoop > 0 && opens == 0 && closes == 0 && !reFor.IsMatch(code) && !string.IsNullOrWhiteSpace(code)) {
        // we set inLoop=depth for one statement; clear if still pending without brace
        if (depth < inLoop || inLoop == depth) {
          if (!loopAwait) outList.AddRange(clockHold);
          clockHold.Clear();
          loopAwait = false;
          loopNames.Clear();
          inLoop = 0;
          pendingLoop = false;
        }
      }
    }
    if (!loopAwait) outList.AddRange(clockHold);
    return outList;
  }

  static List<string> ForNames(string code, Regex reForEachHead, Regex reForInit) {
    var names = new List<string>();
    var fe = reForEachHead.Match(code);
    if (fe.Success) {
      var head = fe.Groups[1].Value;
      var inAt = head.LastIndexOf(" in ", StringComparison.Ordinal);
      if (inAt >= 0) head = head.Substring(0, inAt);
      foreach (Match m in Regex.Matches(head, @"[A-Za-z_]\w*")) {
        var n = m.Value;
        if (n is "var" or "in" or "out" or "ref") continue;
        names.Add(n);
      }
      return names;
    }
    var init = reForInit.Match(code);
    if (init.Success) names.Add(init.Groups[1].Value);
    return names;
  }

  static string FirstArg(Regex re, string code) {
    var m = re.Match(code);
    return m.Success ? m.Groups[1].Value : "";
  }

  static string NthArg(Regex re, string code, int n) {
    var raw = FirstArg(re, code);
    if (raw.Length == 0) return "";
    var parts = raw.Split(',');
    return n < parts.Length ? parts[n] : "";
  }

  static bool ArgUses(string args, List<string> names) {
    if (names.Count == 0 || args.Length == 0) return false;
    foreach (var name in names) {
      int from = 0;
      while (from <= args.Length - name.Length) {
        int i = args.IndexOf(name, from, StringComparison.Ordinal);
        if (i < 0) break;
        bool before = i == 0 || !IdentChar(args[i - 1]);
        int afterAt = i + name.Length;
        bool after = afterAt >= args.Length || !IdentChar(args[afterAt]);
        if (before && after) return true;
        from = i + 1;
      }
    }
    return false;
  }

  static bool IdentChar(char c) => c == '_' || char.IsLetterOrDigit(c);

  static bool LooksStringPlus(string code, Regex reNumPlus)
  {
    if (reNumPlus.IsMatch(code)) return false;
    static bool Numish(string s) =>
      Regex.IsMatch(s, @"^(i|j|k|n|m|x|y|idx|index|count|cnt|len|length|size|offset|start|pos|total|sum|num|bytes?|capacity|hash|hashcode|probe|position|lastnumber|section|value|magnitude|number|dcount|tokenlength|chvalue|width|next|end)$", RegexOptions.IgnoreCase)
      || Regex.IsMatch(s, @"(count|offset|total|sum|index|len|size|pos|num|bytes?|capacity|hashcode|hash|position|section|value|magnitude|width|number)$", RegexOptions.IgnoreCase);
    static bool Stringy(string s) =>
      Regex.IsMatch(s, @"^(s|str|string|msg|message|text|out|buf|buffer|name|path|line|html|body|process|grouped|result)$", RegexOptions.IgnoreCase);
    var lhs = Regex.Match(code, @"(\w+)\s*\+=");
    if (lhs.Success && Numish(lhs.Groups[1].Value)) return false;
    if (lhs.Success && Stringy(lhs.Groups[1].Value)) return true;
    if (code.Contains('"') || code.Contains("string", StringComparison.Ordinal)) return true;
    var m = Regex.Match(code, @"(\w+)\s*\+=\s*([\w.]+)");
    if (m.Success && Numish(m.Groups[2].Value)) return false;
    return false;
  }

  // Blank string/char literal contents (keep braces) so message strings do not trip rules.
  static string BlankStrings(string s)
  {
    var chars = s.ToCharArray();
    bool inStr = false; char q = '\0';
    for (int i = 0; i < chars.Length; i++) {
      var c = chars[i];
      if (inStr) {
        if (c == '\\' && i + 1 < chars.Length) { chars[i] = ' '; chars[i + 1] = ' '; i++; continue; }
        if (c == q) { inStr = false; continue; }
        if (c is not ('{' or '}')) chars[i] = ' ';
        continue;
      }
      if (c is '"' or '\'') { inStr = true; q = c; continue; }
    }
    return new string(chars);
  }

  static string StripLineComment(string s)
  {
    bool inStr = false; char q = '\0';
    for (int i = 0; i < s.Length; i++) {
      var c = s[i];
      if (inStr) {
        if (c == '\\' && i + 1 < s.Length) { i++; continue; }
        if (c == q) inStr = false;
        continue;
      }
      if (c is '"' or '\'') { inStr = true; q = c; continue; }
      if (c == '/' && i + 1 < s.Length && s[i + 1] == '/') return s[..i];
    }
    return s;
  }
}
