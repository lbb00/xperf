# goperf-lint

Heuristic Go checker for **gp-make-in-loop–gp-defer-in-loop**. Line/brace window scanner — not a full SSA pass.

| ID | Smell |
|----|-------|
| gp-make-in-loop | `make`/`new` in loop; reuse buffers when profiles show pressure |
| gp-string-plus-in-loop | string `+=` in loop; prefer `strings.Builder` |
| gp-fmt-in-loop | `fmt.Sprintf`/`Printf` in loop; gate or use cheaper writers |
| gp-append-nil-slice | empty slice grown with `append` in size-hinted loop; prefer `make([]T, 0, n)` |
| gp-defer-in-loop | `defer` in loop; calls accumulate until function returns |

Defaults: gp-make-in-loop–gp-fmt-in-loop **off** (G3 OK-idiom demotion), gp-append-nil-slice/gp-defer-in-loop **hint**. Enable demoted rules with `--severity gp-make-in-loop=hint`. Self-dogfood: `bash ../scripts/self-lint.sh` must stay clean on `cmd/` + `internal/` (fixtures excluded via `fixtures/` skip).
