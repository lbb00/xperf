function bad(root, n) {
  let text = "";
  for (let i = 0; i < n; i++) {
    const node = root.querySelector(".item");
    if (node) text = node.textContent;
  }
  return text;
}
module.exports = { bad };
