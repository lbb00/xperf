## 3. Bridge / console chatter

`console.log` and frequent sync cross-language or worker bridge calls on the hot path stall frames. Gate debug I/O.

Lint: `at-console-hot` (default off).

