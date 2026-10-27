# swiftperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

## Pins

Shallow clones, 2026-10-22 Asia/Shanghai.

| Tree | Commit | Lint r3 → r4 redesign | Notes |
|------|--------|----------------------|-------|
| **swift-nio** | `108daca` `https://github.com/apple/swift-nio.git` | 16 → **20** | sp-array-no-reserve/sp-map-joined-chain |
| **Alamofire** | `bda9ed5` `https://github.com/Alamofire/Alamofire.git` | 1 → **6** | ParameterEncoding sp-map-joined-chain TP |
| **swift-argument-parser** | `efd239f` `https://github.com/apple/swift-argument-parser.git` | 21 → **6** | Usage/Tools/Completions skipped |

**Note (2026-10-22):** no `swift` toolchain. G0–G3 used
[`scripts/text-lint.cjs`](../scripts/text-lint.cjs) (heuristic parity with SPM sources).
Install Swift 5.9+ to build `swiftperf-lint` and re-verify.

**corpus-ready: yes** (r4 redesign; text-lint parity). Defaults: sp-array-no-reserve/sp-map-joined-chain **hint**; sp-force-unwrap-in-loop–sp-print-hot **off**. No G4.

Do not commit corpus sources into `packages/swiftperf`.

## 2026-10-23 — new hint rules, not triaged

The slugs below are **hint**. Each has a JSONL microbench and has not been through G2/G3. The 2026-10-22 corpus-ready verdict does not cover them.

- `sp-dateformatter-hot`, `sp-json-decode-hot`, `sp-regex-hot`
