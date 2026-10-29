## 2. Strings, collections, and printing

Repeated `s += piece` can be costly; prefer reserved capacity / builders when measured. Hot `print` is I/O-bound — gate it. Appending to an empty `Array` in a sized loop reallocates as it grows; call `reserveCapacity` first when the final count is known.

Companion lint: **sp-print-hot** (off; about 10× a `String` when stdout is discarded), **sp-array-no-reserve** (hint; about 5× on many small arrays, about 1.6× on one large fill). String `+=` with `reserveCapacity` was slower, and `map` then `joined` was about 1.2×, so those lints were removed.

