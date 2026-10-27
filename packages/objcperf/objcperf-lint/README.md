# objcperf-lint

Heuristic Objective-C checker. C line-window scanner over `.m`/`.h` — not a full AST/SSA pass. No Apple SDK required for lint.

| Slug | Default | Smell |
|------|---------|-------|
| `oc-nsstring-append-hot` | **off** | `stringByAppendingString` in loop |
| `oc-nslog-hot` | **off** | `NSLog` in loop |
| `oc-dateformatter-hot` | **hint** | date formatter `alloc`/`init` or `new` in a loop |
| `oc-json-hot` | **hint** | JSON parse or encode in a loop |
| `oc-regex-hot` | **hint** | regular expression compiled in a loop |

The two measured rules default to `off`; enable one with `--severity <slug>=hint` (or `error`). The three 2026-10-23 rules default to **hint** until measured. They are not part of the 2026-10-22 corpus-ready verdict.

Removed (jitter 2026-10-22, no slug — see `evidence/_removed/`): `OC001`, `OC004`.
