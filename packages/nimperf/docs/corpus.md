# nimperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.
Lint with:

```sh
packages/nimperf/nimperf-lint/nimperf-lint \
  <corpus-dir>/<name> --format json --no-fail
```

Checker is **Nim** (`nimperf-lint`), same-language. Requires `nim` on PATH (choosenim).
**nm-seq-add-hot–nm-echo-hot default `off`**; **nm-seq-no-capacity hint**.

## Pins

| Tree | URL | Commit | Notes |
|------|-----|--------|-------|
| Nim | https://github.com/nim-lang/Nim | `58130d2` | shallow; 41M |
| Arraymancer | https://github.com/mratsim/Arraymancer | `dcc220c` | shallow; 7.0M |
| nimbus-eth2 | https://github.com/status-im/nimbus-eth2 | `963756c` | shallow; 25M |

## Cloned (2026-10-22) + G3 redesign

| Tree | r2 → r3 (defaults) |
|------|---------------------|
| **Nim** | 112 → **39** |
| **Arraymancer** | 17 → **2** |
| **nimbus-eth2** | 41 → **171** |

### Redesign

- nm-seq-no-capacity: empty seq + `.add` in size-hinted loop; prefer `newSeqOfCap`
- Skip `compiler/`; demote nm-seq-add-hot–nm-echo-hot after OK-idiom domination

Do not commit corpus sources into `packages/nimperf`.
