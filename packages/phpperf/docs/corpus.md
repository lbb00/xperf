# phpperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

## Pins

Shallow clones.

| Tree | Commit | Size |
|------|--------|------|
| **framework** | `6107396` | 46M |
| **symfony** | `ad1bfbb2` | 181M |
| **composer** | `e7417e7` | 13M |

Lint with:

```sh
php packages/phpperf/phpperf-lint/phpperf-lint.php \
  <corpus-dir>/<name> --format json --no-fail
```

Checker is **PHP 8+** (`phpperf-lint`). Rules ph-string-dot-in-loop–ph-echo-in-loop (**ph-string-dot-in-loop default `off`**; **ph-array-merge-rebind default `error`** with G4; ph-echo-in-loop `hint`).

## Dogfood: G3 r2 and post-G4 r3 (2026-10-21 to 2026-10-22, Asia/Shanghai)

| Tree | baseline → r1 → r2 → **r3** |
|------|------------------------------|
| **framework** | 65 → 59 → 48 → **25** (ph-array-merge-rebind:21 ph-echo-in-loop:4) |
| **symfony** | 796 → 636 → 393 → **47** (ph-array-merge-rebind:34 ph-echo-in-loop:13) |
| **composer** | 107 → 103 → 47 → **17** (ph-array-merge-rebind:17) |

**corpus-ready: yes** — after ph-string-dot-in-loop demotion, r3 n=89: TP 79.8%, FP+DOC+SKIP 0%; honest TP on ph-array-merge-rebind; ph-array-merge-rebind error has G4 (`evidence/ph-array-merge-rebind.md`+`jsonl`).

### Reverse-opt

- Path skips: `test(s)/` `Tests/` `Fixtures/` `views/` `vendor/` `Tui/` `.github/` + Resources/bin codegen file skips
- **ph-string-dot-in-loop default `off`** — framework `.=` mostly cold builders/parsers; `--severity ph-string-dot-in-loop=hint` to review
- ph-array-merge-rebind: only `$a = array_merge($a, …)` growing rebind
- ph-echo-in-loop: mask strings; statement-like echo/print

Do not commit corpus sources into `packages/phpperf`.
