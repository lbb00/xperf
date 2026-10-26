# zp-large-struct-by-value — inconclusive

## Status

**inconclusive** — no `evidence/zp-large-struct-by-value.jsonl`. Do not invent one.

## Reason

Large-struct-by-value vs pointer microbench under Zig **0.17.0** `-Ofast` / ReleaseFast was **elided** (~tens of ns total). Numbers do not represent the smell; citing them would be dishonest.

## Why no JSONL

Optimizer removed the work; ratio is noise.

## Unblock

A harness that forces observable copies (opaque / `volatile` / black-box sink, or a real call boundary the optimizer cannot erase) under the optimize mode we care about. Until then the rule stays **off**.
