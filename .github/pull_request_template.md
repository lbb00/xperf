# Pull request

## Summary

<!-- What changed and why -->

## Kits touched

**Core**
- [ ] zperf
- [ ] cperf
- [ ] jsperf
- [ ] jvmperf

**Other kits**
- [ ] goperf
- [ ] pyperf
- [ ] swiftperf
- [ ] arktsperf
- [ ] cppperf (C++17; ≠ cperf)
- [ ] csharpperf
- [ ] phpperf
- [ ] rubyperf
- [ ] rustperf
- [ ] kotlinperf (Kotlin-first; ≠ jvmperf)
- [ ] objcperf (≠ swiftperf)
- [ ] dartperf
- [ ] luaperf
- [ ] beamperf (Elixir + Erlang)
- [ ] nimperf (Nim)

- [ ] shared docs / root / CI only

## Checklist

- [ ] `bash scripts/sync-check.sh` passes (lists all present kits)
- [ ] `bash scripts/doc-check.sh` and `bash scripts/build-guides.sh --check` pass (Markdown or guide changes)
- [ ] `bash scripts/privacy-check.sh --history` passes
- [ ] Ran relevant kit tests / smoke (`make test` / `npm test` / `zig build test` / `./gradlew test` / `scripts/smoke-lint.sh`)
- [ ] Fixtures: bad still fails, good still clean (if lint rules changed)
- [ ] No new default **error** without `evidence/<RULE>.jsonl` (or registered skip stub `.md`)
- [ ] No corpora, `*-corpus/`, or large `*.tar.gz` source dumps in this PR
- [ ] `CHANGELOG.md` `[Unreleased]` updated when user-facing

## Evidence / docs

<!-- Link evidence JSONL, pending stub, guide section, or “N/A docs-only” -->
