# swiftperf-lint

Heuristic Swift checker for **sp-array-no-reserve** through the hot-call hints. Line/brace window scanner.

| Rule | Default | Message |
|------|---------|---------|
| sp-print-hot | off | print in loop |
| sp-array-no-reserve | hint | empty Array then append without reserveCapacity |
| sp-dateformatter-hot | hint | date formatter constructed in a loop |
| sp-json-decode-hot | hint | JSON decoder or jsonObject in a loop |
| sp-regex-hot | hint | regular expression constructed in a loop |

Without the Swift SDK: use `../scripts/text-lint.cjs` (documented parity).
