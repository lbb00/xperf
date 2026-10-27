function good(names) {
  const handlers = [];
  for (const name of names) {
    handlers.push(() => {
      return performance.now();
    });
  }
  return handlers;
}
module.exports = { good };
