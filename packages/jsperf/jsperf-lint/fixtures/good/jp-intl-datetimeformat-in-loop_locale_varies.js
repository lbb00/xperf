function good(rows, locales) {
  const out = [];
  for (let i = 0; i < rows.length; i++) {
    const fmt = new Intl.DateTimeFormat(locales[i]);
    out.push(fmt.format(rows[i]));
  }
  return out;
}
module.exports = { good };
