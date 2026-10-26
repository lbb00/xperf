## 2. Strings and hot I/O

`s += x` in a loop is a classic builder case (`StringBuilder` / `buildString`). Keep `println` out of tight loops. For measured string concat, see jvmperf `jp-string-concat-in-loop`.

