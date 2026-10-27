# Evidence microbench be-map-merge-hot / be-enum-map-filter-chain → packages/beamperf/evidence/*.jsonl
# be-map-merge-hot: Map.merge / Keyword.merge in reduce vs Map.put / one-shot merge
# be-enum-map-filter-chain: Enum.map |> Enum.filter chain vs one-pass reduce
# Timer: :erlang.monotonic_time(:nanosecond); warm=3; median of 9

defmodule Jasonish do
  def encode(map) do
    parts =
      for {k, v} <- map do
        key = "\"#{k}\""
        val =
          cond do
            is_binary(v) -> "\"#{String.replace(v, "\"", "\\\"")}\""
            is_number(v) -> to_string(v)
            true -> "\"#{inspect(v)}\""
          end

        "#{key}:#{val}"
      end

    "{" <> Enum.join(parts, ",") <> "}"
  end
end

defmodule Evidence do
  @rounds 9
  @warm 3

  def median(xs) do
    a = Enum.sort(xs)
    n = length(a)
    mid = div(n, 2)
    if rem(n, 2) == 1, do: Enum.at(a, mid), else: (Enum.at(a, mid - 1) + Enum.at(a, mid)) / 2
  end

  def time_many(fun) do
    for _ <- 1..@warm, do: fun.()

    samples =
      for _ <- 1..@rounds do
        :erlang.garbage_collect()
        t0 = :erlang.monotonic_time(:nanosecond)
        _ = fun.()
        t1 = :erlang.monotonic_time(:nanosecond)
        (t1 - t0) / 1.0e6
      end

    median(samples)
  end

  def emit(rule, pairs) do
    out_dir = System.get_env("EVIDENCE_DIR") || Path.expand("../../evidence", __DIR__)
    File.mkdir_p!(out_dir)
    ts = DateTime.utc_now() |> DateTime.to_iso8601()
    otp = :erlang.system_info(:otp_release) |> List.to_string()

    lines =
      for p <- pairs do
        Jasonish.encode(%{
          rule: rule,
          case: p.case,
          role: p.role,
          elixir: System.version(),
          otp: otp,
          median_ms: p.median_ms,
          ops: p.ops,
          ratio: p.ratio,
          ts: ts
        })
      end

    path = Path.join(out_dir, "#{rule}.jsonl")
    File.write!(path, Enum.join(lines, "\n") <> "\n")
    IO.puts("wrote #{path}")

    for p <- pairs do
      IO.puts("  #{p.role} #{p.case} #{p.median_ms} ratio=#{p.ratio}")
    end
  end
end

n_maps = String.to_integer(System.get_env("BE004_N") || "5000")
n_kw = String.to_integer(System.get_env("BE004_KW_N") || "2000")
n_enum = String.to_integer(System.get_env("BE005_N") || "200000")

# --- be-map-merge-hot Map.merge in reduce vs Map.put ---
maps =
  for i <- 1..n_maps do
    %{i => i, :tag => rem(i, 7)}
  end

# Also many small maps that only add one key each (matches put_in_loop good fixture)
maps_kv =
  for i <- 1..n_maps do
    %{k: i, v: i * 2}
  end

before_merge =
  Evidence.time_many(fn ->
    Enum.reduce(maps, %{}, fn m, acc -> Map.merge(acc, m) end) |> map_size()
  end)

after_put =
  Evidence.time_many(fn ->
    Enum.reduce(maps_kv, %{}, fn %{k: k, v: v}, acc -> Map.put(acc, k, v) end) |> map_size()
  end)

# Fairer pair: same input shape — merge many single-key maps vs put
maps_single =
  for i <- 1..n_maps do
    %{i => i}
  end

before_merge_single =
  Evidence.time_many(fn ->
    Enum.reduce(maps_single, %{}, fn m, acc -> Map.merge(acc, m) end) |> map_size()
  end)

after_put_single =
  Evidence.time_many(fn ->
    Enum.reduce(maps_single, %{}, fn m, acc ->
      [{k, v}] = Map.to_list(m)
      Map.put(acc, k, v)
    end)
    |> map_size()
  end)

# Keyword.merge pair
kw_maps =
  for i <- 1..n_kw do
    [{:"k#{rem(i, 64)}", i}]
  end

before_kw =
  Evidence.time_many(fn ->
    Enum.reduce(kw_maps, [], fn m, acc -> Keyword.merge(acc, m) end) |> length()
  end)

after_kw =
  Evidence.time_many(fn ->
    Enum.reduce(kw_maps, [], fn [{k, v}], acc -> Keyword.put(acc, k, v) end) |> length()
  end)

Evidence.emit("be-map-merge-hot", [
  %{case: "map_put_kv", role: "after", median_ms: after_put, ops: n_maps, ratio: 1.0},
  %{
    case: "map_merge_reduce",
    role: "before",
    median_ms: before_merge,
    ops: n_maps,
    ratio: before_merge / after_put
  },
  %{case: "map_put_single", role: "after", median_ms: after_put_single, ops: n_maps, ratio: 1.0},
  %{
    case: "map_merge_single",
    role: "before",
    median_ms: before_merge_single,
    ops: n_maps,
    ratio: before_merge_single / after_put_single
  },
  %{case: "keyword_put", role: "after", median_ms: after_kw, ops: n_kw, ratio: 1.0},
  %{
    case: "keyword_merge_reduce",
    role: "before",
    median_ms: before_kw,
    ops: n_kw,
    ratio: before_kw / after_kw
  }
])

# --- be-enum-map-filter-chain Enum.map |> Enum.filter vs one-pass ---
xs = Enum.to_list(-div(n_enum, 2)..(div(n_enum, 2) - 1))

before_chain =
  Evidence.time_many(fn ->
    xs |> Enum.map(&(&1 * 2)) |> Enum.filter(&(&1 > 0)) |> length()
  end)

after_one =
  Evidence.time_many(fn ->
    Enum.reduce(xs, [], fn x, acc ->
      y = x * 2
      if y > 0, do: [y | acc], else: acc
    end)
    |> Enum.reverse()
    |> length()
  end)

# Second smell: map |> reject
before_reject =
  Evidence.time_many(fn ->
    xs |> Enum.map(&(&1 + 1)) |> Enum.reject(&(&1 == 0)) |> length()
  end)

after_reject =
  Evidence.time_many(fn ->
    Enum.reduce(xs, [], fn x, acc ->
      y = x + 1
      if y == 0, do: acc, else: [y | acc]
    end)
    |> Enum.reverse()
    |> length()
  end)

Evidence.emit("be-enum-map-filter-chain", [
  %{case: "one_pass_reduce", role: "after", median_ms: after_one, ops: n_enum, ratio: 1.0},
  %{
    case: "map_filter_chain",
    role: "before",
    median_ms: before_chain,
    ops: n_enum,
    ratio: before_chain / after_one
  },
  %{case: "one_pass_reject", role: "after", median_ms: after_reject, ops: n_enum, ratio: 1.0},
  %{
    case: "map_reject_chain",
    role: "before",
    median_ms: before_reject,
    ops: n_enum,
    ratio: before_reject / after_reject
  }
])
