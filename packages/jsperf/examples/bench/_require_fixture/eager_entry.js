'use strict';
// Eager: top-level require always loads heavy.js
const heavy = require('./heavy');
module.exports = function run(needHeavy) {
  if (needHeavy) return heavy.s;
  return 0;
};
