# csharpperf

C# performance notes, small examples, and `csharpperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready**; cs-regex-hot=hint; cs-list-add-no-capacity–cs-console-hot **off** (heuristic; escalation needs evidence JSONL plus a policy decision). Guide v0.

## Contents

- [English guide (v0)](docs/csharp-performance-guide.md) — from `docs/guide-src/`
- [`csharpperf-lint`](csharpperf-lint/README.md) — cs-list-add-no-capacity–cs-regex-hot
- [Corpus pins](docs/corpus.md)

## Focus

Pre-size `List` capacity, avoid quadratic string growth, keep `Console.Write*` out of tight loops.

## Run lint

```sh
cd packages/csharpperf/csharpperf-lint
dotnet build -c Release
dotnet run -c Release --no-build -- path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         pending stubs until benches land
examples/         tiny demos
csharpperf-lint/  checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh (both skip when `dotnet` is absent)
```
