# XPerf

XPerf is a set of performance guides and heuristic linters, one kit per language under `packages/`. A lint hit means “look here,” not “this will be faster.” A rule stays a hint until paired fixtures and a measured before/after promote it. Rule IDs are semantic slugs (~169 active).

## Languages

| Package | Language | Active rules |
|---------|----------|-------------:|
| [zperf](packages/zperf/) | Zig | 31 |
| [cperf](packages/cperf/) | C11/C17 (light C++) | 12 |
| [jsperf](packages/jsperf/) | JavaScript / TypeScript (V8/Node) | 11 |
| [jvmperf](packages/jvmperf/) | Java (JVM) | 29 |
| [goperf](packages/goperf/) | Go | 10 |
| [pyperf](packages/pyperf/) | Python | 6 |
| [swiftperf](packages/swiftperf/) | Swift | 8 |
| [arktsperf](packages/arktsperf/) | ArkTS (HarmonyOS; lint via Node) | 4 |
| [cppperf](packages/cppperf/) | C++17 (separate from cperf) | 6 |
| [csharpperf](packages/csharpperf/) | C# | 10 |
| [phpperf](packages/phpperf/) | PHP | 3 |
| [rubyperf](packages/rubyperf/) | Ruby | 7 |
| [rustperf](packages/rustperf/) | Rust | 7 |
| [kotlinperf](packages/kotlinperf/) | Kotlin (≠ jvmperf JMH) | 3 |
| [objcperf](packages/objcperf/) | Objective-C (≠ swiftperf) | 8 |
| [dartperf](packages/dartperf/) | Dart | 4 |
| [luaperf](packages/luaperf/) | Lua | 3 |
| [beamperf](packages/beamperf/) | Elixir + Erlang (BEAM) | 4 |
| [nimperf](packages/nimperf/) | Nim | 4 |

Versions and defaults: [docs/kits.md](docs/kits.md).

## Quick start

```sh
cd packages/zperf/zperf-lint
zig build -Doptimize=ReleaseFast
./zig-out/bin/zperf-lint ../examples
```

Needs Zig 0.17+. Other languages: that kit’s README, or [docs/quickstart.md](docs/quickstart.md). `bash scripts/sync-check.sh` checks that every package directory is present. Tagged releases ship source kits only — [docs/release.md](docs/release.md).

## Docs

- [Documentation site](https://lbb00.github.io/xperf/) — these guides on GitHub Pages
- [docs/](docs/README.md) — method and kit index
- [docs/release.md](docs/release.md) — what we publish
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [AGENT.md](AGENT.md) — how agents must work this repo (G0–G7, incl. privacy)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) · [SECURITY.md](SECURITY.md) · [CHANGELOG.md](CHANGELOG.md)

## Layout

```text
docs/        Shared docs
packages/    One kit per language
scripts/     sync-check, doc-check, build-guides, privacy-check, pack-source-dist
```

Zig’s `build.zig` lives only under `packages/zperf/zperf-lint/`.

## License

MIT — [LICENSE](LICENSE).

This tree was written end-to-end by Grok Bot. Humans set requirements and reviewed the results.
