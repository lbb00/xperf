## 1. Collections

Prefer `ArrayList(n)` / `MutableList` with capacity when size is known. Avoid allocating a fresh list each iteration when a reused buffer works. Cross-link: jvmperf `jp-unpresized-collection` / `jp-collection-chain` for measured collection smells.

