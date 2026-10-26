# Evidence microbench be-list-concat-reduce–be-io-puts-in-loop → packages/beamperf/evidence/*.jsonl
# Timer: :erlang.monotonic_time(:nanosecond); warm=3; median of 9

Mix.install([]) # no-op when not Mix; script uses plain Elixir

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

  def emit(rule, pairs, meta) do
    out_dir = System.get_env("EVIDENCE_DIR") || Path.expand("../../evidence", __DIR__)
    File.mkdir_p!(out_dir)
    ts = DateTime.utc_now() |> DateTime.to_iso8601()
    lines =
      for p <- pairs do
        Jasonish.encode(%{
          rule: rule,
          case: p.case,
          role: p.role,
          elixir: System.version(),
          otp: :erlang.system_info(:otp_release) |> List.to_string(),
          median_ms: p.median_ms,
          ops: p.ops,
          ratio: p.ratio,
          ts: ts
        })
      end
    path = Path.join(out_dir, "#{rule}.jsonl")
    File.write!(path, Enum.join(lines, "\n") <> "\n")
    IO.puts("wrote #{path}")
    for p <- pairs, do: IO.puts("  #{p.role} #{p.case} #{p.median_ms} ratio=#{p.ratio}")
  end
end

# Minimal JSON without Jason dep
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

n_list = String.to_integer(System.get_env("BE001_N") || "8000")
n_str = String.to_integer(System.get_env("BE002_N") || "20000")
n_io = String.to_integer(System.get_env("BE003_N") || "5000")

# be-list-concat-reduce
before1 =
  Evidence.time_many(fn ->
    Enum.reduce(1..n_list, [], fn i, acc -> acc ++ [i] end) |> length()
  end)
after1 =
  Evidence.time_many(fn ->
    Enum.reduce(1..n_list, [], fn i, acc -> [i | acc] end) |> Enum.reverse() |> length()
  end)
Evidence.emit("be-list-concat-reduce", [
  %{case: "cons_reverse", role: "after", median_ms: after1, ops: n_list, ratio: 1.0},
  %{case: "list_plusplus", role: "before", median_ms: before1, ops: n_list, ratio: before1 / after1}
], %{})

# BE002
before2 =
  Evidence.time_many(fn ->
    Enum.reduce(1..n_str, "", fn i, acc -> acc <> Integer.to_string(i) end) |> byte_size()
  end)
after2 =
  Evidence.time_many(fn ->
    parts = for i <- 1..n_str, do: Integer.to_string(i)
    IO.iodata_to_binary(parts) |> byte_size()
  end)
Evidence.emit("BE002", [
  %{case: "iodata_to_binary", role: "after", median_ms: after2, ops: n_str, ratio: 1.0},
  %{case: "string_diamond_append", role: "before", median_ms: before2, ops: n_str, ratio: before2 / after2}
], %{})

# be-io-puts-in-loop — discard IO by redirecting group leader to a null device
defmodule NullIO do
  def start do
    spawn(fn -> loop() end)
  end
  defp loop do
    receive do
      {:io_request, from, reply_as, {:put_chars, _, _}} ->
        send(from, {:io_reply, reply_as, :ok}); loop()
      {:io_request, from, reply_as, {:put_chars, _}} ->
        send(from, {:io_reply, reply_as, :ok}); loop()
      {:io_request, from, reply_as, _} ->
        send(from, {:io_reply, reply_as, {:error, :enotsup}}); loop()
      :stop -> :ok
      _ -> loop()
    end
  end
end

null = NullIO.start()
old = Process.group_leader()
Process.group_leader(self(), null)
before3 =
  Evidence.time_many(fn ->
    for i <- 1..n_io, do: IO.puts(i)
    n_io
  end)
Process.group_leader(self(), old)
after3 =
  Evidence.time_many(fn ->
    s = Enum.sum(1..n_io)
    Process.group_leader(self(), null)
    IO.puts(s)
    Process.group_leader(self(), old)
    s
  end)
send(null, :stop)
Evidence.emit("be-io-puts-in-loop", [
  %{case: "io_once_after", role: "after", median_ms: after3, ops: n_io, ratio: 1.0},
  %{case: "io_puts_in_loop", role: "before", median_ms: before3, ops: n_io, ratio: before3 / after3}
], %{})
