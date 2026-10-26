'use strict';
// Tiny stand-in for a fat dependency: burn a bit of sync work + export something.
let s = 0;
for (let i = 0; i < 20000; i++) s += i;
module.exports = { s, stamp: Date.now() };
