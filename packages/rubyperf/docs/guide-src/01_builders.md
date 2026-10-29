## 1. Strings, arrays, and hashes

`s += piece` allocates a new string each time; prefer `s << piece` (or a buffer). `arr = arr + [x]` copies; prefer `<<` / `push`.

`Hash#merge` in a loop was removed. On Ruby 4.0.8 the suggested literal build was slower than `merge` (~0.78×, and again ~0.65×) and allocated about twice as many objects. See `evidence/_removed/rb-hash-merge-in-loop.REMOVED.md`.

Companion lint: **rb-string-plus-hot**, **rb-array-plus-rebind**.

