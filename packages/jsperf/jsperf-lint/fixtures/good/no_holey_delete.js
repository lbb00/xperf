"use strict";
function denseClear(arr) {
  for (let i = 0; i < arr.length; i++) {
    arr[i] = undefined;
  }
  return arr;
}
module.exports = { denseClear };
