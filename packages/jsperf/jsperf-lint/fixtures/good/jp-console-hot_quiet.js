"use strict";
/** Quiet loop — no console.* */
function good(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    s = (s + i) | 0;
  }
  return s;
}
module.exports = { good };
