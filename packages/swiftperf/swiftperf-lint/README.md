# swiftperf-lint

Heuristic Swift checker for **sp-array-no-reserve** through the hot-call hints. Line/brace window scanner.

| Rule | Default | Message |
|------|---------|---------|
| sp-print-in-loop | off | print in loop |
| sp-array-no-reserve | hint | empty Array then append without reserveCapacity |
| sp-dateformatter-in-loop | hint | date formatter constructed in a loop |
| sp-json-decode-in-loop | hint | JSON decoder or jsonObject in a loop |
| sp-regex-in-loop | hint | regular expression constructed in a loop |

Without the Swift SDK: use `../scripts/text-lint.cjs` (documented parity).
