# arktsperf-lint

Heuristic ArkTS / TS checker for the five rules below.

| Rule | Default | Message |
|------|---------|---------|
| at-alloc-in-loop | off | allocation-like in loop |
| at-console-in-loop | off | console in loop |
| at-includes-in-loop | hint | indexOf/includes in loop |
| at-json-in-loop | hint | JSON.parse/stringify in loop |
