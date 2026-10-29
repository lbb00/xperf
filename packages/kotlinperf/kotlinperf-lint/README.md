# kotlinperf-lint

Heuristic Kotlin checker. Line/brace window scanner — not a full AST/SSA pass.

| Slug | Default | Smell |
|------|---------|-------|
| `kt-list-add-hot` | **off** | `list.add` / `+=` in loop |
| `kt-string-plus-hot` | **off** | string `+=` in loop |
| `kt-println-hot` | **off** | `println` in loop |

Removed (jitter 2026-10-22, no slug — see `evidence/_removed/`): `KT004`.
