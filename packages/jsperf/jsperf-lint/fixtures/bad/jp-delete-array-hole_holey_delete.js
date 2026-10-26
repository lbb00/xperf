"use strict";
function punch(arr) {
  for (let i = 0; i < arr.length; i += 2) {
    delete arr[i];
  }
  return arr;
}
module.exports = { punch };
