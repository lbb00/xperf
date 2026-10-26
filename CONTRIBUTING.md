# Contributing

Thanks for helping improve **XPerf**. Work lives in `packages/<kit>/`. Keep the
shared loop ([AGENT.md](AGENT.md) for agents; [docs/playbook.md](docs/playbook.md) for humans):

1. Claim in the guide → measurable example or cited upstream evidence.
2. Lint rule only after **corpus ≥3** and **TP/FP triage** (AGENT G2–G3); FP rate must be acceptable.
3. Dogfood: checker source + examples stay clean under default rules;
   intentional anti-patterns live in `fixtures/bad/` (or explicit suppressions).
4. Escalate a rule to default **error** only with paired fixtures **and**
   before/after evidence JSONL (see [docs/rule-regression.md](docs/rule-regression.md)
   and each kit’s `docs/evidence-policy.md`).

Cross-language smell pointers: [docs/smell-catalog.md](docs/smell-catalog.md).
Rule IDs are **per-kit** slugs; jsperf and jvmperf share the `jp-` prefix with disjoint slug sets, so name the kit when citing a `jp-*` rule.

## Before you open a PR

Run from the repo root:

```sh
bash scripts/sync-check.sh
bash scripts/doc-check.sh && bash scripts/build-guides.sh --check   # Markdown or guide changes
bash scripts/privacy-check.sh --history
```

Then build/test the kits you touched. Commands for all languages:
[docs/quickstart.md](docs/quickstart.md). Kit defaults: [docs/kits.md](docs/kits.md).

Docs site, when you change `site-app/` or `mkdocs.yml`:

```sh
bash scripts/build-pages.sh serve
```

**Severity / exit codes:** cperf and jsperf honor presets. zperf and jvmperf may still
fail the process on any finding until presets land — escalate-to-`error` in docs still
requires evidence JSONL (see each kit’s `docs/evidence-policy.md`).

You do not need every toolchain for a docs-only change; say what you ran in the PR.

**License / contributing:** the root [LICENSE](LICENSE) and this file are authoritative.
Package-level `LICENSE` files are not duplicated. Each kit keeps a short
`CONTRIBUTING.md` stub that points here (plus a one-line kit check where useful).

## PR checklist

- [ ] Touched kit(s) still listed as `present` by `scripts/sync-check.sh`
- [ ] `bash scripts/privacy-check.sh --history` passes (no private names, addresses, machine paths or out-of-repo references; see AGENT.md)
- [ ] Guide / README / rule table updated if behavior or severity changed
- [ ] Fixtures: `bad/` still fails, `good/` still clean (or documented suppressions)
- [ ] **No `error` severity without** `packages/<kit>/evidence/<RULE>.jsonl` (or an
      explicit skip stub `.md` registered in the kit evidence policy / rule-regression)
- [ ] **No corpora** in the PR (no `*-corpus/`, no large third-party trees, no
      `*.tar.gz` of sources). Cite URL + commit in `docs/corpus.md` only
- [ ] Evidence JSONL kept small; regen temps not committed
- [ ] Tone: dry technical English

## Package layout checklist (new kit or major add)

- `README.md` (MIT is root [LICENSE](LICENSE) only — do not copy LICENSE into the kit)
- Short `CONTRIBUTING.md` stub pointing at this file
- `docs/guide-src/` (or assembled guide) under `docs/`
- `docs/evidence-policy.md` and `docs/corpus.md` (citations only)
- `examples/` small and buildable/runnable
- `<kit>-lint/` with fixtures good/bad and a short rule table
- `evidence/` for JSONL + honest skip stubs

A new kit follows the same layout; its rules start at **hint** and move to **off** or **error** only through the G3/G4 gates in [AGENT.md](AGENT.md).

## What not to send

- Marketing copy or unverified “N× faster” claims without a named bench or citation
- Full research corpora or Mac/user disk sync blobs
- Secrets, credentials, or private advisory contents in public PRs (see `SECURITY.md`)

## Conduct and security

- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [SECURITY.md](SECURITY.md)

## Changelog

User-facing changes: append bullets under the single current section in [CHANGELOG.md](CHANGELOG.md)
(or open a new SemVer section when cutting a release). Kits carry no version of their own; releases are repo-wide git tags. Do not revive numeric rule IDs.

## First commit / git hygiene

What **should** be tracked: guides, lint sources, fixtures, small `evidence/*.jsonl` + skip stubs, scripts, root OSS meta (LICENSE, NOTICE, SECURITY, CoC, CI).

What **must not** be committed (also in `.gitignore`):

- `*.jar` under `packages/*/lib/` (fetch with `packages/jvmperf/scripts/fetch-lib.sh`)
- Built ELF/Mach-O benches (e.g. `examples/bench/evidence_fill`)
- .NET `obj/`, `bin/Release/`, `bin/Debug/`, `*.pdb`, `*.dll`
- `packages/*/research/*.{log,txt}` probe dumps
- `*-corpus/`, `*.tar.gz`, sync blobs
- `.claude/` (local agent notes)
- Absolute machine paths as the only documented location — prefer repo-relative paths or an env var / CLI argument

Dry-run before the first commit: `git add -n .` and confirm size is sources-only (no multi‑MB jars or binaries).
