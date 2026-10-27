## 6. Constructors, JSON, DOM queries, and date formats

Each hint below is one measured shape. The hint line states that premise. A call that only looks similar is not given that rewrite. Default **`--scope all`** reports these smells everywhere — extreme stacks treat drip-by-drip cost as in-scope even off a loop. Opt in to **`--scope loop`** for the former in-loop-only match. Messages do not tell readers or models that non-loop sites can be ignored.

`new RegExp(pattern)` compiles on every call when the pattern stays the same. A regex literal is cached. If the pattern is the loop variable, or `parts[i]`, the checker does not say to compile once. The bench compiled one fixed pattern, about 4.4× on Node 26.

`JSON.parse` of one unchanged text was about 140× on Node 26 versus parsing once. `JSON.stringify` of an unchanged value is the same shape. A JSONL line, or `rows[i]`, is a different text every iteration. The checker skips an argument that is the loop binding. It does not tell you to fold those lines into one parse.

`querySelector` / `getElementById` of one unchanged selector was about 16× on Node 26, a tiny linkedom document. A selector built from the loop index is not that bench. `new Intl.DateTimeFormat` with unchanged locale and options was about 36× on Node 26; both sides still format. `new Date` is not this rule.

`fs.readFileSync` of one unchanged path was about 114× on Node 26 versus reading once. Under `--scope loop`, only the loop body after `{` is matched (a `for` iterable that runs the read once is then skipped). Under default `--scope all`, the call is reported wherever it appears when the path is stable. A path that changes every iteration (loop binding) is not reported.

`Date.now` was about 26× and `performance.now` about 19× versus one sample, in a tight loop that did not wait. A loop that contains `await`, or a `for await` loop, is not reported for the clock rule. Sample once when a fresh time is not required each call. A rate limiter that must read the clock each pass has nothing to move.

**jp-regex-ctor-in-loop** and **jp-json-in-loop** stay **hint** on the app and engine presets. JSONL exists for those two, and the 2026-10-22 verdict does not cover them. **jp-dom-query-in-loop** (about 16× on Node 26, a tiny linkedom document) and **jp-intl-datetimeformat-in-loop** (about 36× on Node 26, both sides still format) have JSONL and stay **hint**. They are outside that verdict. `--preset all` is error for every rule that still exists.

`Reflect.get` was about 8× and was not given a rule.

Companion lint: **jp-regex-ctor-in-loop**, **jp-json-in-loop**, **jp-dom-query-in-loop**, **jp-intl-datetimeformat-in-loop**, **jp-readfile-sync-in-loop**, **jp-clock-in-loop**.
