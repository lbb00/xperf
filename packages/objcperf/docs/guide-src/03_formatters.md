## 3. Formatters, JSON, and regular expressions

`[[NSDateFormatter alloc] init]`, `[NSDateFormatter new]`, `NSJSONSerialization` (`JSONObjectWithData` / `dataWithJSONObject`), and `NSRegularExpression` (`regularExpressionWithPattern`) inside a loop repeat that setup on every iteration. Create the formatter or expression once, and parse or encode a payload once when the data allows it. These lints are **hint**. Each has a JSONL microbench and stays hint. They are not part of the 2026-10-22 corpus-ready verdict. They do not revive the removed array-capacity rules.

`stringWithContentsOfFile:` of one path was about 450× versus reading once. A path that changes every iteration cannot be hoisted.

`[NSDate date]` every iteration was about 769× versus one sample. A loop that needs a fresh timestamp has nothing to hoist. `NSDateFormatter` stays its own rule.

`valueForKey:` every iteration was about 124× versus reading the field. A name that is not a fixed field cannot be rewritten as a direct read. This is the same family as Go `FieldByName`.

Companion lint: **oc-dateformatter-in-loop**, **oc-json-in-loop**, **oc-regex-in-loop**, **oc-file-read-in-loop**, **oc-clock-in-loop**, **oc-value-for-key-in-loop**.

