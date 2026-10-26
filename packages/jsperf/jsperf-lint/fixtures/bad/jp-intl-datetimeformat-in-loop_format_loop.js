function bad(rows) {
  const out = [];
  for (let i = 0; i < rows.length; i++) {
    const fmt = new Intl.DateTimeFormat("en-US");
    out.push(fmt.format(rows[i]));
  }
  return out;
}
module.exports = { bad };
