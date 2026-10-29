# be-io-puts-in-loop — renamed 2026-10-27 (Asia/Shanghai)

Status: **renamed** to `be-io-puts-hot`. The old slug is a tombstone and **must never be reused**.

Reason: default matching is `--scope all` (not loop-only). Slug names that contain `in-loop` mislead humans and models into treating non-loop sites as out of scope.

Active rule: `be-io-puts-hot`. Opt in to `--scope loop` (or kit-equivalent) for the former in-loop-only match where supported.
