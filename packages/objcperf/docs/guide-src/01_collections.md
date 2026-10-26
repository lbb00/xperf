## 1. Collections

`[[NSMutableArray alloc] init]` then many `addObject:` calls can resize repeatedly. Prefer `arrayWithCapacity:` when `n` is known. No lint rule covers this: the capacity rules were removed after a jitter-controlled retest showed no reliable speedup.

