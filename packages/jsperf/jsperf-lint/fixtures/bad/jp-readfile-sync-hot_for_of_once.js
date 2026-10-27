const fs = require("fs");
function good(file) {
  const out = [];
  for (const ln of fs.readFileSync(file, "utf8").split("\n")) {
    out.push(ln.length);
  }
  return out;
}
module.exports = { good };
