# cperf-lint

Heuristic checker for C/C++ sources, implemented in **C11** (no libclang). Expect false positives.

## Build

```sh
cd packages/cperf/cperf-lint
make          # → ./cperf-lint
# or: ./build.sh
```

## Rules (v0)

| ID | app/engine | all | Summary | FP / suppress notes |
|----|------------|-----|---------|---------------------|
| cp-alloc-in-loop | **error** | error | `malloc`/`calloc`/`realloc` inside a `for`/`while`/`do` body | Evidence `../evidence/cp-alloc-in-loop.*`; thin `return` wrappers skipped; same-line `*2`/`<<1` realloc skipped |
| cp-realloc-grow-one | **error** | error | `realloc(p, … + 1)` / `old+1` style growth | Evidence `../evidence/cp-realloc-grow-one.*`; best-effort scan of 2nd arg |
| cp-printf-in-loop | **off** | error | `printf` / `fprintf` / `puts` in a loop body window | G3 demote (OK-idiom on corpora); dump/debug/`#if 0` suppressions; `--severity cp-printf-in-loop=hint` |
| cp-strlen-in-cond | **hint** | error | `strlen(` in `for`/`while` **condition** | Hoist length; corpus TPs on quickjs intl + gcc attribs |
| cp-strcat-in-loop | **off** | error | `strcat`/`strncat` in loop body | G3 demote (CLI/path OK-idiom); `--severity cp-strcat-in-loop=hint`; macro `\` skipped |
| cp-sprintf-in-loop | **hint** | error | formatted buffer write in a loop body | JSONL present; stays hint; not corpus-triaged |
| cp-fopen-in-loop | **hint** | error | file open in a loop body | JSONL present; stays hint; not corpus-triaged |
| cp-gettime-in-loop | **hint** | error | clock sample in a loop body | bare `time` is not matched; JSONL present; stays hint; not corpus-triaged |
| cp-wide-bool-flags | **hint** | error | four or more full-width boolean flags in one struct | no bit-field in that struct; JSONL present; stays hint; not corpus-triaged |
| cp-regex-in-loop | **hint** | error | `regcomp` in a loop body | `regexec` is not matched; JSONL about 9.7×; stay hint; not corpus-triaged |

## Usage

```sh
./cperf-lint PATH... [--format text|json] [--preset app|engine|all]
./cperf-lint PATH... --severity cp-printf-in-loop=off --severity cp-alloc-in-loop=hint
./cperf-lint PATH... --strict-hints    # hints also fail exit code
./cperf-lint PATH... --no-fail
./cperf-lint --version
```

Default **`--preset app`** (=`engine`): cp-alloc-in-loop/cp-realloc-grow-one error (evidence-gated); cp-strlen-in-cond, cp-sprintf-in-loop, cp-fopen-in-loop, cp-gettime-in-loop, cp-wide-bool-flags, and cp-regex-in-loop hint; cp-printf-in-loop/cp-strcat-in-loop off. Unknown slugs stay hint. See [../docs/evidence-policy.md](../docs/evidence-policy.md). `--severity` applies after the preset.

Text lines look like `path:line: error cp-alloc-in-loop: …` or `… hint cp-printf-in-loop: …`. JSON includes a `"severity"` field. `off` rules are omitted.

Exit `0` if clean, or only hints (unless `--strict-hints`). Exit `1` on any **error**-severity finding. Exit `2` on usage/IO errors. `--no-fail` forces `0` for findings.

## Self-lint (mandatory dogfood)

```sh
make self-lint   # runs ./cperf-lint on src/ + include/; expects 0 findings
make test        # smoke fixtures + preset checks + self-lint
```

## Fixtures

`fixtures/good` should be silent; `fixtures/bad` should emit the matching rule ids. Under default `app`, the bad tree exits `1` because **cp-alloc-in-loop/cp-realloc-grow-one** are error; cp-strlen-in-cond, the 2026-10-23 hints, and cp-regex-in-loop are hint (exit `0` unless `--strict-hints` or `--severity RULE=error`); cp-printf-in-loop/cp-strcat-in-loop need `--preset all` or `--severity`.

Dogfood corpora: `../docs/corpus.md`.

## Evidence

Measured gates: [`../evidence/cp-alloc-in-loop.md`](../evidence/cp-alloc-in-loop.md), [`cp-realloc-grow-one.md`](../evidence/cp-realloc-grow-one.md), [`cp-printf-in-loop.md`](../evidence/cp-printf-in-loop.md). Policy: [`../docs/evidence-policy.md`](../docs/evidence-policy.md).
