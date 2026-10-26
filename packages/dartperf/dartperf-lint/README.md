# dartperf-lint

Heuristic Dart checker for **dt-list-add-empty–dt-growable-add-empty**. Line/brace window scanner — not a full AST/SSA pass.

| Rule | Default | Message |
|------|---------|---------|
| dt-list-add-empty | **off** | List.add grow in loop |
| dt-string-plus-in-loop | **off** | string + in loop |
| dt-print-in-loop | **off** | print in loop |
| dt-growable-add-empty | **hint** | empty List + add in size-hinted loop |

Self-dogfood: `bash ../scripts/self-lint.sh`.
