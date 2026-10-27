# arktsperf-lint

Heuristic ArkTS / TS checker.

| Rule | Default | Message |
|------|---------|---------|
| at-alloc-hot | off | allocation-like pattern; reuse objects/arrays |
| at-console-hot | off | console.*; gate debug |
| at-includes-hot | hint | indexOf/includes → Set / LUT |
| at-json-hot | hint | JSON.parse/stringify; hoist when stable |

**Scope:** default **`--scope all`** (report everywhere). Opt in to **`--scope loop`** for the former in-loop-only match. Former `*-in-loop` slugs were renamed to `*-hot` (tombstoned; never reuse).
