# jvmperf evidence

Per-rule gate pairs (`<RULE>.md` + `<RULE>.jsonl`). Policy: [../docs/evidence-policy.md](../docs/evidence-policy.md). The Policy column is each rule's default severity in `Rule.java`.

| Rule | Files | Policy |
|------|-------|--------|
| jp-boxed-primitive-collection | yes | off |
| jp-string-concat-hot | yes | **error** |
| jp-regex-hot | yes | off |
| jp-format-hot | yes | off |
| jp-unpresized-collection | yes | off |
| jp-boxed-stream | yes | **error** |
| jp-exception-control-flow | yes | off |
| jp-legacy-synchronized-type | removed | see `_removed/` |
| jp-many-boolean-fields | removed | see `_removed/` |
| jp-enum-key-hash-collection | yes | **error** |
| jp-collection-chain | yes | off |
| jp-value-class-boxing | yes | hint |
| jp-lambda-to-non-inline-hot | yes | off |
| jp-lazy-default-mode | md stub | off (pending) |
| jp-data-copy-hot | yes | **error** |
| jp-android-sparse-array | md stub | hint (pending) |
| jp-log-hot | yes | off |
| jp-sleep-polling | md stub | off (pending) |
| jp-finalize | md stub | hint (pending) |
| jp-expensive-alloc-hot | yes | off (negative) |
| jp-hot-heavy-alloc–jp-ui-text-append | md stubs | hot-heavy-alloc and hot-format-log off, the other four hint (pending ART) |
| jp-baos-tobytearray-copy | yes | **error** |
| jp-hot-payload-copy | yes | **error** |
| vt-unsafe-threadlocal-pool | [md stub](vt-unsafe-threadlocal-pool.md) | not shipped / guide-first |
| jp-client-factory-recreate | yes | **error** |
| jp-string-intern-hot | yes | **error** |
| jp-non-static-field-updater | yes | hint |

Raw dumps: `research/bench-results/` (local output, not committed).

Correlate: `research/benches/` (written by `scripts/run-static-vs-hotspot.sh`).
