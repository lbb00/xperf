const fs = require("fs");
function bad(path, n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    s = fs.readFileSync(path).length;
  }
  return s;
}
