# cppperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.
Lint with:

```sh
cd packages/cppperf/cppperf-lint && make
./cppperf-lint <corpus-dir>/<name> --format json --no-fail
```

Checker is **C++17** (`cppperf-lint`). Active rules: `cx-regex-ctor-in-loop`, `cx-endl-in-loop`, `cx-clock-in-loop`, `cx-ifstream-in-loop`, `cx-const-by-value`, `cx-vector-bool`. `cx-string-append-unreserved` was removed (about 1.09×). Rules added in 2026-10-23 are hint and not part of the corpus verdict below. Removed (jitter): CX001/CX003/CX004.

## Pins

Cloned 2026-10-21 (Asia/Shanghai); lint counts r1 → r2 → r3 (redesign).

| Tree | Commit | Size | Lint (baseline → r1 → r2 → **r3**) |
|------|--------|------|-------------------------------------|
| **json** | `ef3d350` shallow `https://github.com/nlohmann/json.git` | 91M | **4 → 0 → 0 → 0** |
| **fmt** | `0fc3163` shallow `https://github.com/fmtlib/fmt.git` | 4.5M | **49 → 11 → 3 → 0** |
| **spdlog** | `76d4580` shallow `https://github.com/gabime/spdlog.git` | 2.3M | **25 → 4 → 1 → 3** (CX004) |

Path skips: `test/`, `tests/`, `Tests/`, `third_party/`, `thirdparty/`,
`benchmarks/`, `benchmark/`, `bench/`, `examples/`, `example/`, `docs/`, `gtest/`,
`gmock/`, `doctest/`, `bundled/`, plus existing `.git` / `vendor` / `build`.

## G3 TP/FP triage (2026-10-22 Asia/Shanghai)

| Stage | n sample | TP | FP | OK-idiom | FP+DOC+SKIP | corpus-ready? |
|-------|----------|----|----|----------|-------------|----------------|
| r1 | 15 | 0% | 20% | 80% | 20% | **no** |
| r2 | 4 | 0% | 0% | 100% | 0% | **no** (OK-idiom / no TP) |
| **r3** (CX004) | **3** | **100%** | 0% | 0% | **0%** | **yes** |

r2→r3: demote CX001–CX003 → **off**; add **CX004** (hint). spdlog 1→**3** honest TP. Severity: CX004 **hint** (no G4 JSONL). CX001, CX003 and CX004 were retired later the same day under jitter control (see [rule-ids.md](rule-ids.md)); the tables above are history.

## Inventory

```text
<corpus-dir>/
  json/
  fmt/
  spdlog/
```

Do not commit corpus sources into `packages/cppperf`.

## 2026-10-23 — new hint rules, not triaged

The slugs below are **hint**. They have not been through G2/G3. The 2026-10-22 corpus-ready verdict does not cover them.

- `cx-clock-in-loop` has JSONL (about 147× vs sampling once) and stays hint.
