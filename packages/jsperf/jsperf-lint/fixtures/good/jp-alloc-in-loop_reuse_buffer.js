"use strict";
/** Clear jp-alloc-in-loop clean counterpart: allocate once outside the loop. */
function good(n) {
  const buf = new Uint8Array(16);
  let s = 0;
  for (let i = 0; i < n; i++) {
    buf[0] = i & 255;
    s = (s + buf[0]) | 0;
  }
  return s;
}
module.exports = { good };
