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
end

n = String.to_integer(System.get_env("BE002_N") || "10000")
chunk = String.duplicate("x", 32)
out_dir = System.get_env("EVIDENCE_DIR") || Path.expand("../../evidence", __DIR__)
ts = DateTime.utc_now() |> DateTime.to_iso8601()

before_ms =
  Evidence.time_many(fn ->
    Enum.reduce(1..n, "", fn _, acc -> acc <> chunk end) |> byte_size()
  end)
after_ms =
  Evidence.time_many(fn ->
    parts = for _ <- 1..n, do: chunk
    IO.iodata_to_binary(parts) |> byte_size()
  end)
n_digits = String.to_integer(System.get_env("BE002_DIGITS") || "20000")
before_d_ms =
  Evidence.time_many(fn ->
    Enum.reduce(1..n_digits, "", fn i, acc -> acc <> Integer.to_string(i) end) |> byte_size()
  end)
after_d_ms =
  Evidence.time_many(fn ->
    parts = for i <- 1..n_digits, do: Integer.to_string(i)
    IO.iodata_to_binary(parts) |> byte_size()
  end)

lines = [
  %{rule: "BE002", case: "iodata_chunks", role: "after", median_ms: after_ms, ops: n, ratio: 1.0},
  %{rule: "BE002", case: "diamond_chunk32", role: "before", median_ms: before_ms, ops: n, ratio: before_ms / after_ms},
  %{rule: "BE002", case: "iodata_digits", role: "after", median_ms: after_d_ms, ops: n_digits, ratio: 1.0},
  %{rule: "BE002", case: "diamond_digits", role: "before", median_ms: before_d_ms, ops: n_digits, ratio: before_d_ms / after_d_ms}
]
otp = :erlang.system_info(:otp_release) |> List.to_string()
encoded =
  for p <- lines do
    Jasonish.encode(Map.merge(p, %{elixir: System.version(), otp: otp, ts: ts}))
  end
path = Path.join(out_dir, "BE002.jsonl")
File.write!(path, Enum.join(encoded, "\n") <> "\n")
IO.puts("wrote #{path}")
IO.inspect({before_ms, after_ms, before_ms / after_ms}, label: :chunks)
IO.inspect({before_d_ms, after_d_ms, before_d_ms / after_d_ms}, label: :digits)
