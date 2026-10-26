'use strict';
// Lazy: require only on the uncommon path
module.exports = function run(needHeavy) {
  if (needHeavy) {
    const heavy = require('./heavy');
    return heavy.s;
  }
  return 0;
};
