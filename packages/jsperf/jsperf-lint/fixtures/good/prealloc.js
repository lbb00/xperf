function good(n) {
  const a = new Array(n);
  for (let i = 0; i < n; i++) {
    a[i] = i;
  }
  return a;
}
module.exports = { good };
