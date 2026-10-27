function good(rows) {
  let n = 0;
  for (let i = 0; i < rows.length; i++) {
    n += rows[i];
  }
  return n;
}
module.exports = { good };
