# dartperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.
Lint with:

```sh
export PATH="$HOME/dart-sdk/bin:$PATH"
cd packages/dartperf/dartperf-lint && dart pub get
dart run bin/dartperf_lint.dart <corpus-dir>/<name> --format json --no-fail
```

Checker is **Dart** (`dartperf-lint`). Rules dt-list-add-empty–dt-growable-add-empty.

## Pins

Cloned 2026-10-21 (Asia/Shanghai), r1.

| Tree | Commit | Size | Lint (baseline → r1) |
|------|--------|------|----------------------|
| **bloc** | `b9be1e2` shallow `https://github.com/felangel/bloc.git` | 64M | **10 → 3** (dt-list-add-empty:3) |
| **dio** | `f1bef46` shallow `https://github.com/cfug/dio.git` | 9.6M | **19 → 5** (dt-list-add-empty:5) |
| **http** | `1217181` shallow `https://github.com/dart-lang/http.git` | 8.8M | **29 → 4** (dt-list-add-empty:4) |

Path skips (r1 reverse-opt): `test/`, `tests/`, `example/`, `examples/`,
`example_dart/`, `example_flutter/`, `scripts/`, `benchmark(s)/`,
`integration_test/`, `fixtures/`, `docs/`, plus `*_test.dart` files and dirs
ending with `_tests` / containing `conformance_test`.

dt-list-add-empty: skip StreamController / Sink / `*C.add` (queue/stream) patterns.

Residual (kept as signal): production `List.add` in bloc LSP helpers, dio
form_data / adapters, http2 frame/flow queues.

## Inventory

```text
<corpus-dir>/
  bloc/
  dio/
  http/
```

Do not commit corpus sources into `packages/dartperf`.

## G3 TP/FP triage (2026-10-22 Asia/Shanghai)

| | r1 n=12 | r2 n=7 |
|--|---------|--------|
| TP | 0% | 0% |
| FP | 33.3% | 0% |
| OK-idiom | 66.7% | **100%** |
| **FP+DOC+SKIP** | **33.3%** | **0%** |

**Corpus-ready? `no`** — BytesBuilder/Headers/Set FPs fixed; residuals are intentional List collects. Keep dt-list-add-empty **hint**.

### Fixes landed
- Non-list `.add` allowlist; `??= []` no longer triggers growAssign
- r2 counts: bloc **3**, dio **2**, http **2**

## Redesign → corpus-ready (2026-10-22 Asia/Shanghai)

| Tree | r2 | r3 (defaults) | corpus-ready? |
|------|----|---------------|---------------|
| bloc | 3 | **0** | |
| dio | 2 | **0** | |
| http | 2 | **1** | |

**Verdict: corpus-ready `yes`.** Sample n=1: TP 100% / FP+DOC+SKIP 0%. Defaults: dt-list-add-empty–dt-print-in-loop **off**; **dt-growable-add-empty** **hint**. Checker is Dart (`dartperf-lint`).
