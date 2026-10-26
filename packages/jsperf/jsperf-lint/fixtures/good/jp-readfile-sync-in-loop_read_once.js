const fs = require("fs");
function good(path, n) {
  const data = fs.readFileSync(path);
  let s = 0;
  for (let i = 0; i < n; i++) {
    s = data.length;
  }
  return s;
}
