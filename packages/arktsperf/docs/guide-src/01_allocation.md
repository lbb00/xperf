## 1. Allocation

Object and array literals, and `new`, inside tight UI or animation loops raise GC pressure. Reuse buffers when the profile shows pressure.

Lint: `at-alloc-hot` (default off).

