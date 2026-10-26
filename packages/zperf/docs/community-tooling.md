# Zig linting tools: scope and comparison

Notes on related Zig linters and where `zperf-lint` fits. Versions drift; re-check upstream before relying on this table.

## Role of `zperf-lint`

It looks for performance and memory patterns that compilers rarely flag: alloc-in-loop, shifting queues, likely padding, empty I/O buffers, and similar source signals. Checks are syntax-based heuristics. They do not replace compile, profile, benchmark, or general linting.

CI runs it with community tools via `zig run scripts/repo.zig -- lint-all`: correctness tools block; style or version-mismatched checks are advisory. Umbrella CI pins live in the repo-root [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) (job `zperf`). Nested package workflows were removed; see [`ci/README.md`](../ci/README.md).

## Design boundaries

- Add a rule only when the source pattern has a clear performance consequence.
- Document false-positive risk and a suppression path.
- Stay off type analysis unless the compiler API exposes it reliably.
- Treat findings as prompts for measurement — a lint hit is not a measured speedup.

Rules and limits: [`zperf-lint`](../zperf-lint/README.md). CI: [root `ci.yml`](../../../.github/workflows/ci.yml) · [`ci/README.md`](../ci/README.md).
