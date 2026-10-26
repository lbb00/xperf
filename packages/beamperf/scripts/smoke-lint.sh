#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$ROOT/beamperf-lint/beamperf_lint.exs"
export BEAMPERF_LINT_NO_MAIN=1
elixir --eval '
lint = System.argv() |> hd()
Code.compile_file(lint)
bad_dir = Path.join([Path.dirname(lint), "fixtures", "bad"])
good_dir = Path.join([Path.dirname(lint), "fixtures", "good"])
erl = Path.join(bad_dir, "be-list-concat-reduce_list_plus.erl")
exs = Path.join(bad_dir, "be-list-concat-reduce_list_plus.exs")
be4 = Path.join(bad_dir, "be-map-merge-in-loop_merge_in_loop.exs")
be5 = Path.join(bad_dir, "be-enum-map-filter-chain_enum_chain.exs")

sev_all_err = %{"be-list-concat-reduce"=>"error","be-io-puts-in-loop"=>"error","be-map-merge-in-loop"=>"error","be-enum-map-filter-chain"=>"error"}
sev_def = %{"be-list-concat-reduce"=>"hint","be-io-puts-in-loop"=>"off","be-map-merge-in-loop"=>"hint","be-enum-map-filter-chain"=>"hint"}

count = fn finds, sev ->
  Enum.count(finds, fn f -> Map.get(sev, f.rule, "hint") != "off" end)
end
rules_of = fn finds, sev ->
  finds |> Enum.filter(&(Map.get(sev, &1.rule, "hint") != "off")) |> Enum.map(& &1.rule) |> Enum.uniq()
end

bad_n = count.(BeamperfLint.scan_path(bad_dir), sev_all_err)
good_n = count.(BeamperfLint.scan_path(good_dir), sev_def)
exs_n = count.(BeamperfLint.scan_path(exs), sev_def)
erl_n = count.(BeamperfLint.scan_path(erl), sev_def)
be4_rules = rules_of.(BeamperfLint.scan_path(be4), sev_def)
be5_rules = rules_of.(BeamperfLint.scan_path(be5), sev_def)
erl_err = rules_of.(BeamperfLint.scan_path(erl), Map.put(sev_def, "be-list-concat-reduce", "error"))

cond do
  bad_n < 4 -> IO.puts(:stderr, "fail: bad too few #{bad_n}"); System.halt(1)
  good_n != 0 -> IO.puts(:stderr, "fail: good dirty #{good_n}"); System.halt(1)
  exs_n < 1 -> IO.puts(:stderr, "fail: be-list-concat-reduce exs"); System.halt(1)
  erl_n < 1 -> IO.puts(:stderr, "fail: be-list-concat-reduce erl hint"); System.halt(1)
  "be-map-merge-in-loop" not in be4_rules -> IO.puts(:stderr, "fail: be-map-merge-in-loop"); System.halt(1)
  "be-enum-map-filter-chain" not in be5_rules -> IO.puts(:stderr, "fail: be-enum-map-filter-chain"); System.halt(1)
  "be-list-concat-reduce" not in erl_err -> IO.puts(:stderr, "fail: be-list-concat-reduce erl error"); System.halt(1)
  true -> IO.puts("beamperf-lint smoke ok")
end
' "$LINT"
