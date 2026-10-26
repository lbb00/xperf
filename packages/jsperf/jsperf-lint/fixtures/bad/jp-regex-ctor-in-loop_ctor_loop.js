function bad(parts) {
  let n = 0;
  for (let i = 0; i < parts.length; i++) {
    const re = new RegExp("a+");
    if (re.test(parts[i])) n++;
  }
  return n;
}
module.exports = { bad };
