function good(parts) {
  const re = new RegExp("a+");
  let n = 0;
  for (let i = 0; i < parts.length; i++) {
    if (re.test(parts[i])) n++;
  }
  return n;
}
module.exports = { good };
