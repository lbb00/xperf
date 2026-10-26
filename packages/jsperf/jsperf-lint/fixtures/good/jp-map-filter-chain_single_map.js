function good(items) {
  const out = [];
  for (let i = 0; i < items.length; i++) {
    const x = items[i] * 2;
    if (x > 0) out.push(x);
  }
  return out;
}
module.exports = { good };
