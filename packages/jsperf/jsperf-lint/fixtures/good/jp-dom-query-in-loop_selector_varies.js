function good(root, ids) {
  const out = [];
  for (let i = 0; i < ids.length; i++) {
    const node = root.querySelector("#" + ids[i]);
    if (node) out.push(node.textContent);
  }
  return out;
}
module.exports = { good };
