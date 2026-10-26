// Empty {} / [] binders are not jp-alloc-in-loop (options/ctx bags).
function good(n) {
  const out = [];
  for (let i = 0; i < n; i++) {
    const opts = {};
    const buf = [];
    out.push(i);
  }
  return out;
}
module.exports = { good };
