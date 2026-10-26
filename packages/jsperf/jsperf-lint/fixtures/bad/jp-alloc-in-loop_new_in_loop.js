function bad(n) {
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push(new Map());
  }
  return out;
}
module.exports = { bad };
