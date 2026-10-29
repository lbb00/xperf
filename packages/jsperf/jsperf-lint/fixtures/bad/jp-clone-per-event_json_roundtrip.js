function bad(handler) {
  return function onData(e) {
    const copy = JSON.parse(JSON.stringify(e));
    handler(copy);
  };
}
module.exports = { bad };
