# cs-regex-hot — Regex.IsMatch(pattern) in loop

**Status:** measured

## Claim

Calling `Regex.IsMatch(name, pattern)` each iteration is slower than one `RegexOptions.Compiled` instance (~2.58× on .NET 10.0.13).

## How measured

- Harness: EvidenceCsBench
- N=50000; pattern `^[a-z]+$`

- Raw lines: [`cs-regex-hot.jsonl`](cs-regex-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| dotnet | **8.0.32** |
| Median before (`regex_ismatch_loop`) | 4.1372 ms |
| Median after (`compiled_regex`) | 1.6045 ms |
| **ratio before/after** | **~2.58×** |

## Lint mapping

`csharpperf-lint` cs-regex-hot: keep default severity.

## Limits

- Modest ratio; default stays **hint**; do not escalate to error on ~2.6× alone.

## Constructor shape

`new Regex` every iteration versus one instance. Both sides still call `IsMatch` on `id-2026`. 2000 ops. Before 3.453 ms, after 0.483 ms, ratio 7.145. The matcher now flags `new Regex(` as well as the static `Regex.IsMatch` / `Match` calls. Default stays **hint**.
