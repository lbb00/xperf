## 3. Bridge / console chatter

`console.log` and frequent sync cross-language / worker bridge calls on the hot path stall frames. Gate debug I/O.

Companion lint: **at-console-hot**.

