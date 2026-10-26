# rustperf corpus targets

Large trees are **not** vendored, and the corpus is not shipped with the repo: clone it into any local directory outside the repo and pass that path to the linter.

## Pins

| Tree | URL | Commit | Size | Lint scope |
|------|-----|--------|------|------------|
| serde | https://github.com/serde-rs/serde.git | `0db9b3b504bcb0a7fa9cf001429869519afd3e9a` | ~3.1M | whole tree |
| tokio | https://github.com/tokio-rs/tokio.git | `cffdc7601134598cebc45d03af0358dedfcb3ff1` | ~7.9M sparse | `tokio/` cone |
| clap | https://github.com/clap-rs/clap.git | `ccc89b83875474399e9d9d70841163f6319d1a41` | ~6.5M | whole tree |

Shallow clones (`--depth 1`). Tokio uses sparse-checkout for the `tokio/` crate only.

## Dogfood + G3 (through r4 redesign, 2026-10-22 Asia/Shanghai)

| Tree | Raw | r1 | r2 | r3-split | r3 (rs-alloc-in-loop off) | **r4 (rs-vec-no-capacity/rs-collect-vec-in-loop)** |
|------|-----|----|----|----------|----------------|----------------------|
| serde | **64** | 43 | 29 | 11 | **0** | **0** |
| tokio | **148** | 15 | 3 | 3 | **0** | **0** |
| clap | **287** | 124 | 78 | 69 | **5** | **6** (rs-collect-vec-in-loop:2 rs-vec-no-capacity:3 rs-string-plus-in-loop:1) |

Rule order: rs-alloc-in-loop / rs-string-plus-in-loop / rs-println-in-loop / rs-format-rebind-in-loop / **rs-vec-no-capacity** / **rs-collect-vec-in-loop**.

**corpus-ready: yes** — r4 n=6 all **TP** (clap wrap collect + sized `Vec::new`+push + val-name `push_str`); FP+DOC+SKIP **0%**; serde/tokio clean under defaults.

### Reverse-opt (`rustperf-lint`)

1. **`--raw-paths`:** disables reverse-opt for baseline dumps.
2. **Path skips:** `tests/` `test/` `benches/` … + **`tests.rs`** + inline **`#[cfg(test)]`/`#[test]`**.
3. **Loop heads:** real `for x in` / `while` / `loop` only — not `impl Trait for Type` or `for<'a>`.
4. **rs-alloc-in-loop default `off`** — Id/`to_owned`/syn clones dominate; `--severity rs-alloc-in-loop=hint` to review.
5. **rs-string-plus-in-loop:** `+=` / `push_str` only (**hint**); skip shells/clap_complete/mangen; skip error/help/styled/debug; tiny seps; skip `mid_string`/`sc_names` seeds in `command.rs`.
6. **rs-format-rebind-in-loop:** `ident = format!(…)` rebind reuse (**error**, G4 ~99×); skip one-shot `"{{{ident}}}"` brace wrap.
7. **rs-println-in-loop:** skip example/demo bins, `cfg!(debug_assertions)`, `counters.rs`.
8. **rs-vec-no-capacity:** empty `Vec`/`String`/`vec![]` then grow in **size-hinted** loop (**hint**); skip derive crates + cold CLI.
9. **rs-collect-vec-in-loop:** `collect::<Vec…>` inside real loop (**hint**); keep textwrap/styled_str; skip cold CLI templates/shells.

### Residual (not speed claims)

- r4 clap-only: wrap-path collects + sized conflict/subcommand vec builders + arg value-name `push_str` — all triaged **TP**.
- rs-vec-no-capacity/rs-collect-vec-in-loop stay **hint**: measured G4 ratios are modest (see [evidence-policy.md](evidence-policy.md)).
- No invented ratios.

Do not commit corpus sources into `packages/rustperf`.

## 2026-10-23 — new hint rules, not triaged

The slugs below are **hint**. They have paired fixtures and a pending evidence note. They have **no** JSONL and have **not** been through G2/G3. The 2026-10-22 corpus-ready verdict does not cover them.
