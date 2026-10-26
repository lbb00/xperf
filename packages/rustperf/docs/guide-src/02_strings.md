## 2. Strings and hot I/O

`format!("{s}…")` / `s = format!(…)` accumulation in a loop is alloc-heavy (copies the growing prefix) — **rs-format-rebind-in-loop**. Prefer `with_capacity` + `write!`, or collect then join. Plain `+=` / `push_str` on one growing `String` was about 1× versus `with_capacity` on a large fill, so that lint was removed. Keep `println!` / `eprintln!` out of tight loops (gate or buffer).

A large `Vec::new` plus `push` was about 1× versus `with_capacity`, so that lint was removed. Avoid `.collect::<Vec<_>>()` inside per-item loops when a reused buffer or streaming count will do (**rs-collect-vec-in-loop**).

