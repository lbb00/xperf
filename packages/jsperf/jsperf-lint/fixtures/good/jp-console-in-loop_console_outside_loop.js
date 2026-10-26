"use strict";
/** Clear jp-console-in-loop clean counterpart: console outside the hot loop. */
function good(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    s = (s + i) | 0;
  }
  console.log("done", s);
  return s;
}
module.exports = { good };
