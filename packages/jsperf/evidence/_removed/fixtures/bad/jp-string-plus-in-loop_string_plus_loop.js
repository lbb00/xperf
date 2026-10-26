function bad(parts) {
  let s = "";
  for (let i = 0; i < parts.length; i++) {
    s += `${parts[i]}`;
    s += ",";
  }
  return s;
}
module.exports = { bad };
