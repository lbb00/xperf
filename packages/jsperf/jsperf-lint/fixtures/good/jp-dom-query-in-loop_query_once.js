function good(root) {
  const node = root.querySelector(".item");
  let n = 0;
  for (let i = 0; i < 10; i++) {
    n += node ? 1 : 0;
  }
  return n;
}
module.exports = { good };
