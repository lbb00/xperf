## 1. Lists

`List.add` in a hot loop is fine when capacity growth amortizes, but allocating a fresh growable list every iteration is not. Prefer `List.filled` / `List.generate` / known length when possible.

Companion lint: **dt-list-add-empty**, **dt-growable-add-empty** (empty growable list + `add` in a size-hinted loop).

