#!/usr/bin/env elixir
# beamperf-lint — heuristic Elixir/Erlang performance checker

defmodule BeamperfLint do
  @msg %{
    "be-list-concat-reduce" => "list ++; prefer cons + reverse / accumulator — cost adds up even off a hot path",
    # BE002 removed 2026-10-22 — see evidence/_removed/
    "be-io-puts-hot" => "IO.puts / io:format; gate or buffer — cost adds up even off a hot path",
    "be-map-merge-hot" => "Map/Keyword.merge; use Map.put, or merge outside only when the other map stays the same — cost adds up even off a hot path",
    "be-enum-map-filter-chain" => "chained Enum.map/filter allocates an intermediate; cost grows with length. One pass was faster on the measured chain; a short list is a different cost"
  }

  @rules ["be-list-concat-reduce", "be-io-puts-hot", "be-map-merge-hot", "be-enum-map-filter-chain"]


  def main(argv) do
    {opts, paths, _} =
      OptionParser.parse(argv,
        strict: [
          help: :boolean,
          format: :string,
          severity: :keep,
          scope: :string,
          strict_hints: :boolean,
          no_fail: :boolean
        ],
        aliases: [h: :help]
      )

    cond do
      opts[:help] -> usage(0)
      paths == [] -> usage(2)
      true -> :ok
    end

    sev =
      Enum.reduce(Keyword.get_values(opts, :severity), default_sev(), fn spec, acc ->
        case String.split(spec, "=", parts: 2) do
          [rule, level] when level in ["off", "hint", "error"] ->
            if rule in @rules do
              Map.put(acc, rule, level)
            else
              usage(2)
            end

          _ ->
            usage(2)
        end
      end)

    format = opts[:format] || "text"
    scope = opts[:scope] || "all"
    if scope not in ["all", "loop"], do: usage(2)
    findings = Enum.flat_map(paths, fn path -> scan_path(path, scope) end)
    {nerr, nhint} = emit(findings, sev, format)

    cond do
      opts[:no_fail] -> System.halt(0)
      nerr > 0 or (opts[:strict_hints] == true and nhint > 0) -> System.halt(1)
      true -> System.halt(0)
    end
  end

  # G3 redesign 2026-10-22: BE002/be-io-puts-hot → off; be-map-merge-hot/be-enum-map-filter-chain corpus-mined hint; be-list-concat-reduce keeps hint (+ Erlang Acc++)
  defp default_sev,
    do: %{
      "be-list-concat-reduce" => "hint",
      # BE002 removed
      "be-io-puts-hot" => "off",
      "be-map-merge-hot" => "hint",
      "be-enum-map-filter-chain" => "hint"
    }

  defp usage(code) do
    IO.puts(:stderr, """
    Usage: beamperf_lint.exs PATH... [options]
      --format text|json
      --severity RULE=error|hint|off
      --scope all|loop     (default: all; loop = former in-loop-only)
      --strict-hints
      --no-fail
    Scans .ex .exs .erl
    Rules: #{Enum.join(@rules, " ")}
    """)

    System.halt(code)
  end

  defp beam_ext?(path) do
    Path.extname(path) in [".ex", ".exs", ".erl"]
  end

  defp skip_dir?(name),
    do:
      name in [
        ".git",
        "fixtures",
        "_build",
        "deps",
        "node_modules",
        "vendor",
        "test",
        "tests",
        "examples",
        "example",
        "docs",
        "benchmark",
        "benchmarks",
        "tmp",
        "scripts",
        "iex",
        "integration_test"
      ]

  def scan_path(root, scope \\ "all") do
    cond do
      File.regular?(root) ->
        if beam_ext?(root), do: scan_file(root, scope), else: []

      File.dir?(root) ->
        root
        |> Path.join("**/*.{ex,exs,erl}")
        |> Path.wildcard()
        |> Enum.reject(fn p ->
          rel = Path.relative_to(p, root)
          Enum.any?(Path.split(rel), &skip_dir?/1)
        end)
        |> Enum.flat_map(fn p -> scan_file(p, scope) end)

      true ->
        []
    end
  end

  def scan_file(path, scope \\ "all") do
    case File.read(path) do
      {:ok, text} -> do_scan(path, text, scope)
      _ -> []
    end
  end

  defp strip_comment(line, erl?) do
    strip_chars(String.to_charlist(line), false, nil, [], erl?)
  end

  defp strip_chars([], _, _, acc, _), do: acc |> Enum.reverse() |> List.to_string()

  defp strip_chars([?\\, n | rest], true, q, acc, erl?),
    do: strip_chars(rest, true, q, [n, ?\\ | acc], erl?)

  defp strip_chars([c | rest], true, q, acc, erl?) when c == q,
    do: strip_chars(rest, false, nil, [c | acc], erl?)

  defp strip_chars([c | rest], true, q, acc, erl?),
    do: strip_chars(rest, true, q, [c | acc], erl?)

  defp strip_chars([c | rest], false, _, acc, erl?) when c in [?", ?'],
    do: strip_chars(rest, true, c, [c | acc], erl?)

  # # is comment in Elixir and Erlang. % is Erlang-only (Elixir uses %{} maps).
  defp strip_chars([?# | _], false, _, acc, _),
    do: acc |> Enum.reverse() |> List.to_string()

  defp strip_chars([?% | _], false, _, acc, true),
    do: acc |> Enum.reverse() |> List.to_string()

  defp strip_chars([c | rest], false, _, acc, erl?),
    do: strip_chars(rest, false, nil, [c | acc], erl?)

  defp do_scan(path, text, scope \\ "all") do
    lines = String.split(text, ~r/\r\n|\n|\r/)
    erl? = Path.extname(path) == ".erl"

    {findings, _, _, _, _} =
      Enum.reduce(Enum.with_index(lines, 1), {[], 0, 0, false, :code}, fn {raw, line_no},
                                                                          {out, depth, in_loop, in_fn, mode} ->
        {mode2, in_doc} = doc_mode(mode, raw)
        code = strip_comment(raw, erl?)
        do_n = length(Regex.scan(~r/\bdo\b(?!:)/, code))
        end_n = length(Regex.scan(~r/\bend\b/, code))
        fn_n = length(Regex.scan(~r/\bfn\b/, code))

        loop_here =
          not in_doc and
            (Regex.match?(~r/\b(for|while)\b/, code) or
               Regex.match?(~r/\bEnum\.(each|map|reduce|flat_map|map_join)\b/, code) or
               Regex.match?(~r/\bStream\.(each|map|reduce|flat_map)\b/, code) or
               Regex.match?(~r/\blists:(foreach|map|foldl|foldr)\b/, code) or
               Regex.match?(~r/\breceive\b/, code))

        in_fn2 = if fn_n > 0, do: true, else: in_fn
        in_loop2 = if loop_here, do: max(depth, 0) + 1, else: in_loop

        erl_acc = erl? and not in_doc and erl_acc_append?(code)

        match_here =
          scope == "all" or
            (in_loop2 > 0 and depth >= in_loop2) or (in_fn2 and in_loop2 > 0) or
            (loop_here and smell_line?(code))

        active =
          not in_doc and
            (erl_acc or match_here)

        out2 =
          if not in_doc do
            maybe_add_be005(out, path, line_no, code)
          else
            out
          end

        out2 =
          if active do
            out2
            |> maybe_add_be001(path, line_no, code)
            # BE002 removed 2026-10-22
            |> maybe_add_io(path, line_no, code)
            |> maybe_add_be004(path, line_no, code, loop_here)
          else
            out2
          end

        depth2 = depth + do_n + fn_n - end_n
        depth2 = if depth2 < 0, do: 0, else: depth2
        in_fn3 = if in_fn2 and end_n > 0 and depth2 < depth, do: false, else: in_fn2
        in_loop3 = if in_loop2 > 0 and depth2 < in_loop2, do: 0, else: in_loop2
        {out2, depth2, in_loop3, in_fn3, mode2}
      end)

    Enum.reverse(findings)
  end

  defp erl_acc_append?(code) do
    Regex.match?(~r/\bAcc\s*\+\+\s*\[/, code) or
      Regex.match?(~r/\b([A-Za-z_]\w*)\s*=\s*\1\s*\+\+/, code) or
      Regex.match?(~r/\bAcc\d*\s*=\s*Acc\d*\s*\+\+\s*\[/, code)
  end

  defp doc_mode(mode, raw) do
    trimmed = String.trim_leading(raw)

    cond do
      mode == :code and Regex.match?(~r/^@(?:moduledoc|doc|typedoc)\s+"""/, trimmed) ->
        if count_heredoc(trimmed) >= 2, do: {:code, false}, else: {:heredoc, true}

      mode == :code and Regex.match?(~r/^@(?:moduledoc|doc|typedoc)\s+"/, trimmed) and
          not String.contains?(trimmed, ~s(""")) ->
        {:code, true}

      mode == :heredoc ->
        if String.contains?(raw, ~s(""")) , do: {:code, true}, else: {:heredoc, true}

      true ->
        in_doc =
          String.starts_with?(trimmed, "iex>") or String.starts_with?(trimmed, "...> ")

        {mode, in_doc}
    end
  end

  defp count_heredoc(s), do: length(Regex.scan(~r/"""/, s))

  defp smell_line?(code) do
    Regex.match?(~r/\+\+/, code) or Regex.match?(~r/(?<!<)<>(?!>)/, code) or
      Regex.match?(~r/\bIO\.(puts|write|inspect)\b/, code) or
      Regex.match?(~r/\bio:format\b/, code) or Regex.match?(~r/:io\.format\b/, code) or
      Regex.match?(~r/\b(Map|Keyword)\.merge\(/, code) or
      Regex.match?(~r/\bmaps:merge\(/, code)
  end

  defp maybe_add_be001(out, path, line, code) do
    cond do
      Regex.match?(~r/@\w+/, code) ->
        out

      String.contains?(code, "<-") ->
        out

      Regex.match?(~r/\b([A-Za-z_]\w*)\s*=\s*\1\s*\+\+/, code) ->
        [%{rule: "be-list-concat-reduce", path: path, line: line, message: @msg["be-list-concat-reduce"]} | out]

      Regex.match?(~r/\b(acc|xs|ys|list|rest|Acc)\s*\+\+\s*\[/, code) ->
        [%{rule: "be-list-concat-reduce", path: path, line: line, message: @msg["be-list-concat-reduce"]} | out]

      Regex.match?(~r/\bAcc\d*\s*=\s*Acc\d*\s*\+\+\s*\[/, code) ->
        [%{rule: "be-list-concat-reduce", path: path, line: line, message: @msg["be-list-concat-reduce"]} | out]

      true ->
        out
    end
  end

  # defp maybe_add_be002 removed 2026-10-22

  defp maybe_add_io(out, path, line, code) do
    if Regex.match?(~r/\bIO\.(puts|write|inspect)\b/, code) or
         Regex.match?(~r/\bio:format\b/, code) or
         Regex.match?(~r/:io\.format\b/, code) do
      [%{rule: "be-io-puts-hot", path: path, line: line, message: @msg["be-io-puts-hot"]} | out]
    else
      out
    end
  end

  defp maybe_add_be004(out, path, line, code, loop_here) do
    cond do
      loop_here ->
        out

      Regex.match?(~r/\b(Map|Keyword)\.merge\(/, code) or Regex.match?(~r/\bmaps:merge\(/, code) ->
        [%{rule: "be-map-merge-hot", path: path, line: line, message: @msg["be-map-merge-hot"]} | out]

      true ->
        out
    end
  end

  defp maybe_add_be005(out, path, line, code) do
    # Nested &(&1) breaks [^)]*; match rule names across the pipe only.
    chained =
      Regex.match?(
        ~r/\bEnum\.(map|filter|flat_map|reject)\b.{0,200}\|>\s*Enum\.(map|filter|flat_map|reject|uniq)\b/,
        code
      ) or
        Regex.match?(
          ~r/\|\>\s*Enum\.(map|filter|flat_map|reject)\b.{0,200}\|>\s*Enum\.(map|filter|flat_map|reject|uniq)\b/,
          code
        )

    if chained do
      [%{rule: "be-enum-map-filter-chain", path: path, line: line, message: @msg["be-enum-map-filter-chain"]} | out]
    else
      out
    end
  end

  defp emit(findings, sev, format) do
    {rows, nerr, nhint} =
      Enum.reduce(findings, {[], 0, 0}, fn f, {rows, nerr, nhint} ->
        level = Map.get(sev, f.rule, "hint")

        cond do
          level == "off" ->
            {rows, nerr, nhint}

          true ->
            nerr2 = if level == "error", do: nerr + 1, else: nerr
            nhint2 = if level == "error", do: nhint, else: nhint + 1

            row =
              if format == "json" do
                ~s({"rule":"#{f.rule}","severity":"#{level}","path":"#{f.path}","line":#{f.line},"message":"#{f.message}"})
              else
                "#{f.path}:#{f.line}: #{level} #{f.rule}: #{f.message}"
              end

            {[row | rows], nerr2, nhint2}
        end
      end)

    rows = Enum.reverse(rows)

    if format == "json" do
      IO.puts("[" <> Enum.join(rows, ",") <> "]")
    else
      if rows != [], do: IO.puts(Enum.join(rows, "\n"))
      shown = nerr + nhint

      if shown > 0 do
        IO.puts(:stderr, "#{shown} finding(s) (#{nerr} error, #{nhint} hint)")
      else
        IO.puts(:stderr, "ok")
      end
    end

    {nerr, nhint}
  end
end

unless System.get_env("BEAMPERF_LINT_NO_MAIN") == "1" do
  BeamperfLint.main(System.argv())
end
