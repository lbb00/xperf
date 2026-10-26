# pyperf-lint

Heuristic Python checker for **pp-str-plus-in-loop / pp-list-plus-rebind / pp-print-in-loop**.

| ID | Smell |
|----|-------|
| pp-str-plus-in-loop | string `+=` in loop |
| pp-list-plus-rebind | list `+` rebinding in loop |
| pp-print-in-loop | `print(` in loop |

Defaults: pp-str-plus-in-loop/pp-print-in-loop **off**, pp-list-plus-rebind **hint**. PP004 removed (see `evidence/_removed/`).
