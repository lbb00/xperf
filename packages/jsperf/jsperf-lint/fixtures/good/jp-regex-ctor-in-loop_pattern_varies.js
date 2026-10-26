function good(parts) {
  let n = 0;
  for (let i = 0; i < parts.length; i++) {
    const re = new RegExp(parts[i]);
    if (re.test("x")) n++;
  }
  return n;
}
function goodWord(words) {
  let n = 0;
  for (const word of words) {
    const re = new RegExp(word);
    if (re.test("x")) n++;
  }
  return n;
}
module.exports = { good, goodWord };
