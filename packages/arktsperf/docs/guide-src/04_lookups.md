## 4. Lookups and JSON in loops

`Array.includes` / `indexOf` over a list inside a hot loop is linear per iteration; build a `Set` once and use `has`. For short strings, a dense lookup table beats `Map` (a `Map` often loses on short haystacks). Parsing or stringifying many small JSON values in a loop repeats allocation and parsing work; parse one array blob or reuse buffers.

Companion lint: **at-includes-hot**, **at-json-hot** (both default **hint**). Their JSONL evidence is a Node proxy, not an ArkTS VM, so it cannot raise severity on its own.

