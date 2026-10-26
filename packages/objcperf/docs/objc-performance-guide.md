# Objective-C performance guide (v0)

Foundation collection / string / logging checklists. Distinct from **swiftperf**.

> **Scope: Objective-C (ARC or MRC).** Lint is a line-window scan of `.m`/`.h`. Measure on device/macOS before escalating.

## How to read this

1. **Measure first** (Instruments Time Profiler / Allocations).
2. Treat each chapter as a checklist, not a rewrite mandate.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Collections](#1-collections)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [3. Formatters, JSON, and regular expressions](#3-formatters-json-and-regular-expressions)
- [Lint map](#lint-map)

## 1. Collections

`[[NSMutableArray alloc] init]` then many `addObject:` calls can resize repeatedly. Prefer `arrayWithCapacity:` when `n` is known. No lint rule covers this: the capacity rules were removed after a jitter-controlled retest showed no reliable speedup.

## 2. Strings and hot I/O

`stringByAppendingString:` in a loop allocates many immutable strings. Prefer `NSMutableString`. Keep `NSLog` out of tight loops (gate or use os_log carefully).

Companion lint: **oc-nsstring-append-in-loop**, **oc-nslog-in-loop**.

## 3. Formatters, JSON, and regular expressions

`[[NSDateFormatter alloc] init]`, `[NSDateFormatter new]`, `NSJSONSerialization` (`JSONObjectWithData` / `dataWithJSONObject`), and `NSRegularExpression` (`regularExpressionWithPattern`) inside a loop repeat that setup on every iteration. Create the formatter or expression once, and parse or encode a payload once when the data allows it. These lints are **hint**. Each has a JSONL microbench and stays hint. They are not part of the 2026-10-22 corpus-ready verdict. They do not revive the removed array-capacity rules.

`stringWithContentsOfFile:` of one path was about 450× versus reading once. A path that changes every iteration cannot be hoisted.

`[NSDate date]` every iteration was about 769× versus one sample. A loop that needs a fresh timestamp has nothing to hoist. `NSDateFormatter` stays its own rule.

`valueForKey:` every iteration was about 124× versus reading the field. A name that is not a fixed field cannot be rewritten as a direct read. This is the same family as Go `FieldByName`.

Companion lint: **oc-dateformatter-in-loop**, **oc-json-in-loop**, **oc-regex-in-loop**, **oc-file-read-in-loop**, **oc-clock-in-loop**, **oc-value-for-key-in-loop**.

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| oc-nsstring-append-in-loop | stringByAppendingString in loop | off |
| oc-nslog-in-loop | NSLog in loop | off |
| oc-dateformatter-in-loop | date formatter alloc/init or new in a loop | hint (JSONL present; not corpus-triaged) |
| oc-json-in-loop | JSON parse or encode in a loop | hint (JSONL present; not corpus-triaged) |
| oc-regex-in-loop | regular expression compiled in a loop | hint (JSONL present; not corpus-triaged) |

Escalate only with `evidence/oc-*.jsonl` — see [evidence-policy.md](evidence-policy.md). The two array-capacity rules (OC001, OC004) were removed; see [rule-ids.md](rule-ids.md). `oc-dateformatter-in-loop`, `oc-json-in-loop`, and `oc-regex-in-loop` have a JSONL microbench and stay hint. They are not part of the 2026-10-22 corpus-ready verdict.

## References

- [XPerf playbook](../../../docs/playbook.md)
- [swiftperf](../../swiftperf/) (sibling)
