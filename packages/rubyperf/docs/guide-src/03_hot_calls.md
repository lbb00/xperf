## 3. Compile and parse

`Regexp.new` compiles on every call. A regexp literal is cached. `JSON.parse` / `generate` on a fixed payload repeats the parse. A changing payload cannot be hoisted. These lints are **hint** and have a microbench. `Date.parse` / `Time.parse` / `DateTime.parse` was removed for the same reason as a fixed-string parse: the after side only wins by not parsing.

`File.read` of one path was about 346× versus reading once. `File.open` is the same lint. A path that changes every iteration cannot be hoisted. `Process.clock_gettime` was about 2.3× and `send` about 1.9×; those were checked and not given a rule.

Companion lint: **rb-regexp-new-in-loop**, **rb-json-in-loop**, **rb-file-read-in-loop**.
