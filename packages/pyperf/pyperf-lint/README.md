# pyperf-lint

Heuristic Python checker for **pp-str-plus-hot / pp-list-plus-rebind / pp-print-hot**.

| ID | Smell |
|----|-------|
| pp-str-plus-hot | string `+=` in loop |
| pp-list-plus-rebind | list `+` rebinding in loop |
| pp-print-hot | `print(` in loop |

Defaults: pp-str-plus-hot/pp-print-hot **off**, pp-list-plus-rebind **hint**. PP004 removed (see `evidence/_removed/`).
