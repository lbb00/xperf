function good(rows) {
  const out = [];
  for (let i = 0; i < rows.length; i++) {
    out.push(JSON.parse(rows[i]));
  }
  return out;
}
function goodLines(lines) {
  const out = [];
  for (const line of lines) {
    out.push(JSON.parse(line));
  }
  return out;
}
module.exports = { good, goodLines };
