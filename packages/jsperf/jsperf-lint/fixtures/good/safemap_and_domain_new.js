function good(items) {
  const out = [];
  for (const x of items) {
    // Primordials / domain classes: not jp-alloc-hot under clear-ctor policy
    const slot = new SafeMap();
    const node = new TreeNode(x);
    out.push(x);
  }
  return out;
}
// stubs so the file parses in isolation
function SafeMap() {}
function TreeNode() {}
module.exports = { good };
