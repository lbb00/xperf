function good(root) {
  let n = 0;
  for (const el of root.querySelectorAll(".item")) {
    n += el ? 1 : 0;
  }
  return n;
}
module.exports = { good };
