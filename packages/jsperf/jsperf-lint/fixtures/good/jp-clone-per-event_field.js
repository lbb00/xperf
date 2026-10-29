function good(handler) {
  return function onMessage(event) {
    handler(event.data);
  };
}
module.exports = { good };
