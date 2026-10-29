# rubyperf-lint

Pure-Ruby CLI heuristic checker for **rb-string-plus-hot–rb-file-read-hot**. `rb-hash-merge-in-loop` was removed.

| Rule | Default | Message |
|------|---------|---------|
| rb-string-plus-hot | **off** | string `+=` in loop; prefer `<<` |
| rb-array-plus-rebind | **off** | Array `+` / concat rebinding in loop; prefer `<<` |
| rb-puts-hot | **off** | `puts` / `print` in loop; gate or buffer |

Self-dogfood: `bash ../scripts/self-lint.sh`. Corpus-ready after G3 redesign — see [`../docs/corpus.md`](../docs/corpus.md).
