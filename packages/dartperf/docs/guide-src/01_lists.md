## 1. Lists

`List.add` in a hot loop is fine when capacity growth amortizes, but allocating a fresh growable list every iteration is not. Prefer `List.filled` / `List.generate` / known length when possible.

Lint: `dt-list-add-empty` (default off); `dt-growable-add-empty` (empty growable list + `add` in a size-hinted loop; default hint).

