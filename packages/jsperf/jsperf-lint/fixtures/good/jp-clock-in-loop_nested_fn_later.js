function good(methods) {
  const out = Object.create(null);
  for (const method of methods) {
    out[method] = function logLater() {
      return Date.now();
    };
  }
  return out;
}
module.exports = { good };
