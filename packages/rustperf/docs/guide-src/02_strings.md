## 2. Strings and hot I/O

`format!("{s}…")` / `s = format!(…)` accumulation in a loop is alloc-heavy (copies the growing prefix). Prefer `with_capacity` + `write!`, or collect then join. Plain `+=` / `push_str` on one growing `String` was about 1× versus `with_capacity` on a large fill, so that lint was removed. Keep `println!` / `eprintln!` out of tight loops (gate or buffer).

A large `Vec::new` plus `push` was about 1× versus `with_capacity`, so that lint was removed. Avoid `.collect::<Vec<_>>()` inside per-item loops when a reused buffer or streaming count will do.

Lint: `rs-format-rebind-hot` (default error; G4: ~99× vs `write!`); `rs-println-hot`, `rs-collect-vec-hot` (default hint).

