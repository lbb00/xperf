async function good(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    s = Date.now();
    s = performance.now();
    await Promise.resolve();
  }
  return s;
}
async function goodForAwait(xs) {
  let s = 0;
  for await (const x of xs) {
    s = Date.now() + x;
  }
  return s;
}
module.exports = { good, goodForAwait };
