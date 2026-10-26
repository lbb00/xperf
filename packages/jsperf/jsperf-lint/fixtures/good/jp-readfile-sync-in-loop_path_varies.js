const fs = require("fs");
function good(files) {
  let n = 0;
  for (let i = 0; i < files.length; i++) {
    n += fs.readFileSync(files[i]).length;
  }
  return n;
}
module.exports = { good };
