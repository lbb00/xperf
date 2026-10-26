# cs-console-in-loop — Console.WriteLine in loop

**Status:** measured

## Claim

Per-iteration `Console.WriteLine` to `TextWriter.Null` is slower than quiet loop + one write (~17.9× on .NET 10.0.13).

## How measured

- Harness: EvidenceCsBench
- N=20000; Console redirected to Null

- Raw lines: [`cs-console-in-loop.jsonl`](cs-console-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| dotnet | **8.0.32** |
| Median before (`console_in_loop`) | 0.2333 ms |
| Median after (`console_once`) | 0.0130 ms |
| **ratio before/after** | **~17.95×** |

## Lint mapping

`csharpperf-lint` cs-console-in-loop: keep default severity.

## Limits

- Env-dependent; default stays **off**.
