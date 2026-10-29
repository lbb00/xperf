# nimperf-lint

Heuristic Nim checker for **nm-seq-add-hot**, **nm-echo-hot** and **nm-seq-no-capacity**. `nm-string-amp-in-loop` was removed.

| ID | Smell |
|----|-------|
| nm-seq-add-hot | seq `.add` in loop |
| nm-echo-hot | `echo` in loop |
| nm-seq-no-capacity | empty seq + `.add` in size-hinted loop; prefer `newSeqOfCap` |

Defaults: nm-seq-add-hot and nm-echo-hot **off**; nm-seq-no-capacity **hint**. Override with `--severity RULE=error|hint|off`; `--strict-hints` makes hints fail the exit code. See [evidence policy](../docs/evidence-policy.md).
