# objcperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

## Pins

| Tree | URL | Commit | Size | Lint scope |
|------|-----|--------|------|------------|
| AFNetworking | https://github.com/AFNetworking/AFNetworking.git | `d9f589cc2c1fe9d55eb5eea00558010afea7a41e` | ~3.5M | whole tree |
| SDWebImage | https://github.com/SDWebImage/SDWebImage.git | `c3ad5e1a9bf55c9b76d4c362430b5fcded96c502` | ~45M | whole tree |
| fmdb | https://github.com/ccgus/fmdb.git | `d3abf748a2788471535993286603322ccdd02c3d` | ~1.1M | whole tree |

Shallow clones (`--depth 1`). Pure ObjC trees (no Swift-only pods).

## Dogfood (2026-10-21 Asia/Shanghai)

| Tree | Raw (`--raw-paths`) | After reverse-opt |
|------|---------------------|-------------------|
| AFNetworking | **7** (OC001:7) | **4** (4/0/0) |
| SDWebImage | **9** (8/0/1) | **1** (1/0/0) |
| fmdb | **28** (1/1/26) | **10** (1/1/8) |

Rule order: OC001 / oc-nsstring-append-in-loop / oc-nslog-in-loop.

### Reverse-opt (`objcperf-lint`)

1. **`--raw-paths`:** baseline toggle.
2. **Path skips:** `Tests/` `tests/` `Test/` `Example/` `Examples/` `Demo/` `sample/` `Sample/` `docs/` `Specs/` `benchmarks/` (plus always `.git`/`Pods`/`Carthage`/`vendor`/`fixtures`).
3. **OC001:** match `addObject:` / `addObject]` only — **not** `addObjectsFromArray` (substring FP).
4. **oc-nslog-in-loop:** skip `DEBUG`/`NDEBUG` tokens and Debug/Logger path names.

### Residual

- AFNetworking query/cert collection `addObject:` without nearby capacity (real-ish).
- fmdb `FMDatabase.m` diagnostic `NSLog` in bind/close paths (library debug; kept).
- one `stringByAppendingString` version-normalization in fmdb.

Do not commit corpus sources into `packages/objcperf`.

## G3 TP/FP triage (2026-10-22 Asia/Shanghai)

| | r1 n=15 | r2 n=9 |
|--|---------|--------|
| TP | 13.3% | 22.2% |
| FP | 20.0% | 0% |
| OK-idiom | 66.7% | **77.8%** |
| **FP+DOC+SKIP** | **20.0%** | **0%** |

**Corpus-ready? `no`** — OK-idiom dominant after fixing `setWithCapacity` FP. Mild TPs remain (query/cert arrays without capacity). Keep **hint**.

### Fixes landed
- OC001 recognizes `setWithCapacity` / `dictionaryWithCapacity`
- oc-nslog-in-loop skips nearby `DEBUG` / `_traceExecution`
- r2 counts: AFNetworking **2**, SDWebImage **1**, fmdb **6**

## Redesign → corpus-ready (2026-10-22 Asia/Shanghai)

| Tree | r2 | r3 (defaults) | corpus-ready? |
|------|----|---------------|---------------|
| AFNetworking | 2 | **2** | |
| SDWebImage | 1 | **1** | |
| fmdb | 6 | **0** | |

**Verdict: corpus-ready `yes`.** Sample n=3: TP 66.7% / OK-idiom 33.3% / FP+DOC+SKIP 0%. Defaults at the time: OC001–oc-nslog-in-loop **off**; **OC004** **hint**. Heuristic path — no Apple SDK required for G0–G3 (OC001 G4 still blocked without `Foundation.h` on this machine).

OC001 and OC004 were removed afterwards (see [rule-ids.md](rule-ids.md)). At that point the lint shipped only `oc-nsstring-append-in-loop` and `oc-nslog-in-loop`, both default **off**.

## 2026-10-23 — new hint rules, not triaged

The slugs below are **hint**. Each has a JSONL microbench and has not been through G2/G3. The 2026-10-22 corpus-ready verdict does not cover them.

- `oc-dateformatter-in-loop`, `oc-json-in-loop`, `oc-regex-in-loop`
