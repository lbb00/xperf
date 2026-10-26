# nimperf-lint

Heuristic Nim checker for **nm-seq-add-in-loop**, **nm-echo-in-loop** and **nm-seq-no-capacity**. `nm-string-amp-in-loop` was removed.

| ID | Smell |
|----|-------|
| nm-seq-add-in-loop | seq `.add` in loop |
| nm-echo-in-loop | `echo` in loop |
| nm-seq-no-capacity | empty seq + `.add` in size-hinted loop; prefer `newSeqOfCap` |

Defaults: nm-seq-add-in-loop and nm-echo-in-loop **off**; nm-seq-no-capacity **hint**. Override with `--severity RULE=error|hint|off`; `--strict-hints` makes hints fail the exit code. See [evidence policy](../docs/evidence-policy.md).
