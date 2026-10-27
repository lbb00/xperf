function bad(text, n) {
  let out = null;
  for (let i = 0; i < n; i++) {
    out = JSON.parse(text);
  }
  return out;
}
module.exports = { bad };
