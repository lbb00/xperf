function bad(handler) {
  return function onMessage(event) {
    const copy = structuredClone(event);
    handler(copy);
  };
}
module.exports = { bad };
