## 2. Binaries / strings and hot I/O

`a <> b` (Elixir) or repeated binary append in a loop rebuilds binaries. Prefer iolists / `IO.iodata_to_binary/1`. No lint rule covers this smell (its former rule, `BE002`, was retired). Keep `IO.puts` / `:io.format` / `io:format` out of tight loops.

Companion lint: **be-io-puts-in-loop** (default **off**).

