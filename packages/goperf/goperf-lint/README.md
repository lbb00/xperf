# goperf-lint

Heuristic Go checker for **gp-make-hot–gp-defer-hot**. Line/brace window scanner — not a full SSA pass.

| ID | Smell |
|----|-------|
| gp-make-hot | `make`/`new` in loop; reuse buffers when profiles show pressure |
| gp-string-plus-hot | string `+=` in loop; prefer `strings.Builder` |
| gp-fmt-hot | `fmt.Sprintf`/`Printf` in loop; gate or use cheaper writers |
| gp-append-nil-slice | empty slice grown with `append` in size-hinted loop; prefer `make([]T, 0, n)` |
| gp-defer-hot | `defer` in loop; calls accumulate until function returns |

Defaults: gp-make-hot–gp-fmt-hot **off** (G3 OK-idiom demotion), gp-append-nil-slice/gp-defer-hot **hint**. Enable demoted rules with `--severity gp-make-hot=hint`. Self-dogfood: `bash ../scripts/self-lint.sh` must stay clean on `cmd/` + `internal/` (fixtures excluded via `fixtures/` skip).
