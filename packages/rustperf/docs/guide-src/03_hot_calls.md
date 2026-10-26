## 3. Regex

`Regex::new` inside a loop recompiles the pattern. On `regex` 1.13.1 and rustc 1.99, constructing every iteration and matching a short haystack was about 963× versus constructing once (both sides still match). This lint is **hint**. `HashMap::new` plus one insert, 20000 times, was about 1.5× versus clearing one map on two quiet rustc 1.99 runs (`rs-map-new-in-loop`, hint).

`File::open` of one path was about 416× on rustc 1.99 versus opening once. `Instant::now` was about 20× on rustc 1.99 versus one sample. A changing path cannot be hoisted, and a loop that needs a fresh timestamp has nothing to hoist.

Companion lint: **rs-regex-new-in-loop**, **rs-file-open-in-loop**, **rs-clock-in-loop**.
