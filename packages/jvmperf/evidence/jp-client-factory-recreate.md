# jp-client-factory-recreate

## Claim

Recreating an HTTP client factory (`HttpClient.newHttpClient()` stand-in for OkHttpClient/etc.) is extremely expensive vs reuse.

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- The before loop calls `close()` so each client releases its selector. Without that, JDK 27 hits the process fd limit before the iteration finishes.
- **before:** `HttpClient_newEach`
- **after:** `HttpClient_reuse`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **81763.736** ns_per_op, **32558.095** B/op |
| after | **0.416** ns_per_op, **0.000** B/op |
| **ratio before/after** | **~1.97e5×** |

## Lint mapping / policy

Policy **error** (~1.97e5× vs reuse, including `close()`; ~32.6 KB/op on create). Fixture names OkHttp; measured with JDK HttpClient as honest expensive factory.

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
