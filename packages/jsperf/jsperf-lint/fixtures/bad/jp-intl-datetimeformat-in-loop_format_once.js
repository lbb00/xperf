function good(rows) {
  const fmt = new Intl.DateTimeFormat("en-US");
  let n = 0;
  for (let i = 0; i < rows.length; i++) {
    n += fmt.format(new Date(rows[i])).length;
  }
  return n;
}
module.exports = { good };
