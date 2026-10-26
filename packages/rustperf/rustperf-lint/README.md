# rustperf-lint

Heuristic Rust checker for **rs-alloc-in-loop–rs-collect-vec-in-loop**. Line/brace window scanner — not a full AST/SSA pass.

| Rule | Default | Message |
|------|---------|---------|
| rs-alloc-in-loop | off | alloc/clone in loop (Vec::new / .clone / to_string / to_owned); demoted after G3 OK-idiom |
| rs-println-in-loop | hint | println! / eprintln! in loop |
| rs-format-rebind-in-loop | **error** | `format!` rebind accum in loop (~99× vs `write!`); skips `"{{{id}}}"` wrap |
| rs-collect-vec-in-loop | hint | `collect::<Vec<_>>` inside a loop — reuse buffer / avoid per-iter collect |

Self-dogfood: `bash ../scripts/self-lint.sh` must stay clean on examples (fixtures excluded via `fixtures/` skip).

## False positives / reverse-opt

- Init / config loops that intentionally allocate once per entry (rs-alloc-in-loop)
- Cold clap usage seeds (`mid_string` / `sc_names`) and help/shell generators
- Inline `#[cfg(test)]` / `#[test]` regions
- One-shot `s = format!("{{{s}}}")` usage braces (rs-format-rebind-in-loop skipped)

**corpus-ready: yes** (r4 TRIAGE — see `docs/corpus.md`).
