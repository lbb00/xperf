function bad(obj) {
  delete obj.hotField;
  return obj;
}
module.exports = { bad };
