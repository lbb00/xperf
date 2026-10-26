function good(items) {
  let cache;
  for (const x of items) {
    cache ??= new Map();
    cache.set(x, x);
  }
  return cache;
}
module.exports = { good };
