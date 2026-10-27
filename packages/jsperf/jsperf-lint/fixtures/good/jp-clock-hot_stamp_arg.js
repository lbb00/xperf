function good(n, t0) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    s = t0 + i;
  }
  return s;
}
module.exports = { good };
