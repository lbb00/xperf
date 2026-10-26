# rubyperf-lint

Pure-Ruby CLI heuristic checker for **rb-string-plus-in-loop–rb-file-read-in-loop**. `rb-hash-merge-in-loop` was removed.

| Rule | Default | Message |
|------|---------|---------|
| rb-string-plus-in-loop | **off** | string `+=` in loop; prefer `<<` |
| rb-array-plus-rebind | **off** | Array `+` / concat rebinding in loop; prefer `<<` |
| rb-puts-in-loop | **off** | `puts` / `print` in loop; gate or buffer |

Self-dogfood: `bash ../scripts/self-lint.sh`. Corpus-ready after G3 redesign — see [`../docs/corpus.md`](../docs/corpus.md).
