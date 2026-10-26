## 2. Strings and hot I/O

`a .. b` in a loop builds many temporaries. Prefer collecting parts then `table.concat`. Keep `print` out of tight loops (gate or buffer).

