## 2. Strings and hot I/O

`stringByAppendingString:` in a loop allocates many immutable strings. Prefer `NSMutableString`. Keep `NSLog` out of tight loops (gate or use os_log carefully).

Companion lint: **oc-nsstring-append-in-loop**, **oc-nslog-in-loop**.

