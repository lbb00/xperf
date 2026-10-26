using System.Diagnostics;
using System.Globalization;
using System.Text.Json;

static class EvidenceCsRest
{
    const int Rounds = 9, Warm = 3;

    static double Median(List<double> xs)
    {
        var a = xs.ToList();
        a.Sort();
        int n = a.Count, m = n / 2;
        return n % 2 == 1 ? a[m] : 0.5 * (a[m - 1] + a[m]);
    }

    static double TimeMany(string name, Func<int> fn)
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
        double med = Median(samples);
        Console.WriteLine(name + " median_ms=" + med.ToString("F3", CultureInfo.InvariantCulture)
            + " samples " + string.Join(" ", samples.Select(s => s.ToString("F3", CultureInfo.InvariantCulture))));
        return med;
    }

    static void Emit(string rule, (string Case, string Role, double Ms, int Ops)[] pairs)
    {
        string? dir = Environment.GetEnvironmentVariable("EVIDENCE_DIR");
        string ts = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture);
        double lastAfter = 1;
        var lines = new List<string>();
        foreach (var p in pairs)
        {
            if (p.Role == "after") lastAfter = p.Ms;
            double ratio = p.Ms / lastAfter;
            lines.Add(string.Format(CultureInfo.InvariantCulture,
                "{{\"rule\":\"{0}\",\"case\":\"{1}\",\"role\":\"{2}\",\"dotnet\":\"{3}\",\"median_ms\":{4},\"ops\":{5},\"ratio\":{6},\"ts\":\"{7}\"}}",
                rule, p.Case, p.Role, Environment.Version, p.Ms, p.Ops, ratio, ts));
        }
        if (!string.IsNullOrEmpty(dir))
        {
            Directory.CreateDirectory(dir);
            string path = Path.Combine(dir, rule + ".jsonl");
            File.WriteAllText(path, string.Join("\n", lines) + "\n");
            Console.WriteLine("wrote " + path);
        }
        Console.WriteLine("dotnet=" + Environment.Version);
    }

    static void ListBench()
    {
        int n = 200000;
        var src = Enumerable.Range(0, n).ToArray();
        double before = TimeMany("list_add_nocap", () =>
        {
            var list = new List<int>();
            for (int i = 0; i < src.Length; i++) list.Add(src[i]);
            return list.Count;
        });
        double after = TimeMany("list_capacity", () =>
        {
            var list = new List<int>(src.Length);
            for (int i = 0; i < src.Length; i++) list.Add(src[i]);
            return list.Count;
        });
        Emit("cs-list-add-no-capacity", new[]
        {
            ("list_capacity", "after", after, n),
            ("list_add_nocap", "before", before, n),
        });
    }

    static void ClockBench()
    {
        int n = 100000;
        double after = TimeMany("sample_once", () =>
        {
            long t = Stopwatch.GetTimestamp();
            int s = 0;
            for (int i = 0; i < n; i++) s += (int)(t & 1);
            return s;
        });
        double before = TimeMany("sample_each_iter", () =>
        {
            int s = 0;
            for (int i = 0; i < n; i++) s += (int)(Stopwatch.GetTimestamp() & 1);
            return s;
        });
        Emit("cs-clock-in-loop", new[]
        {
            ("sample_once", "after", after, n),
            ("sample_each_iter", "before", before, n),
        });
    }

    static void FileBench()
    {
        int n = 2000;
        string path = Path.Combine(Path.GetTempPath(), "xperf-one-byte.txt");
        File.WriteAllText(path, "x");
        double after = TimeMany("read_once", () =>
        {
            string text = File.ReadAllText(path);
            int s = 0;
            for (int i = 0; i < n; i++) s += text.Length;
            return s;
        });
        double before = TimeMany("read_each_iter", () =>
        {
            int s = 0;
            for (int i = 0; i < n; i++) s += File.ReadAllText(path).Length;
            return s;
        });
        Emit("cs-file-read-in-loop", new[]
        {
            ("read_once", "after", after, n),
            ("read_each_iter", "before", before, n),
        });
    }

    static void JsonBench()
    {
        int n = 20000;
        string payload = "{\"n\":1,\"s\":\"hello\"}";
        double after = TimeMany("deserialize_once", () =>
        {
            var row = JsonSerializer.Deserialize<Row>(payload);
            int s = 0;
            for (int i = 0; i < n; i++) s += row.n;
            return s;
        });
        double before = TimeMany("deserialize_same_payload", () =>
        {
            int s = 0;
            for (int i = 0; i < n; i++) s += JsonSerializer.Deserialize<Row>(payload).n;
            return s;
        });
        Emit("cs-json-in-loop", new[]
        {
            ("deserialize_once", "after", after, n),
            ("deserialize_same_payload", "before", before, n),
        });
    }

    static void FieldBench()
    {
        int n = 20000;
        var obj = new Box { A = 7 };
        double after = TimeMany("direct_field", () =>
        {
            int s = 0;
            for (int i = 0; i < n; i++) s += obj.A;
            return s;
        });
        double before = TimeMany("getfield_each", () =>
        {
            int s = 0;
            for (int i = 0; i < n; i++) s += (int)typeof(Box).GetField("A").GetValue(obj);
            return s;
        });
        Emit("cs-field-by-name-in-loop", new[]
        {
            ("direct_field", "after", after, n),
            ("getfield_each", "before", before, n),
        });
    }

    static void FormatBench()
    {
        int n = 50000;
        double after = TimeMany("tostring", () =>
        {
            int s = 0;
            for (int i = 0; i < n; i++) s += i.ToString().Length;
            return s;
        });
        double before = TimeMany("format_each_iter", () =>
        {
            int s = 0;
            for (int i = 0; i < n; i++) s += string.Format("{0}", i).Length;
            return s;
        });
        Emit("cs-format-in-loop", new[]
        {
            ("tostring", "after", after, n),
            ("format_each_iter", "before", before, n),
        });
    }

    static void LinqBench()
    {
        int n = 20000;
        int[] src = Enumerable.Range(0, 32).ToArray();
        double after = TimeMany("tolist_once", () =>
        {
            var list = src.ToList();
            int s = 0;
            for (int i = 0; i < n; i++) s += list.Count;
            return s;
        });
        double before = TimeMany("tolist_each_iter", () =>
        {
            int s = 0;
            for (int i = 0; i < n; i++) s += src.ToList().Count;
            return s;
        });
        Emit("cs-linq-materialize-in-loop", new[]
        {
            ("tolist_once", "after", after, n),
            ("tolist_each_iter", "before", before, n),
        });
    }

    static int Main(string[] args)
    {
        string which = args.Length > 0 ? args[0] : "";
        switch (which)
        {
            case "list": ListBench(); break;
            case "clock": ClockBench(); break;
            case "file": FileBench(); break;
            case "json": JsonBench(); break;
            case "field": FieldBench(); break;
            case "format": FormatBench(); break;
            case "linq": LinqBench(); break;
            default:
                Console.Error.WriteLine("usage: list|clock|file|json|field|format|linq");
                return 2;
        }
        Console.WriteLine("DONE_CS_" + which.ToUpperInvariant());
        return 0;
    }

    sealed class Box { public int A; }
    sealed class Row { public int n { get; set; } public string s { get; set; } }
}
