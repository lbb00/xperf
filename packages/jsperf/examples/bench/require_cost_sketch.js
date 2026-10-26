'use strict';
/**
 * Teaching sketch: eager top-level require vs lazy require on the rare path.
 * Not a claim about npm or any real package — wipe require cache between trials.
 *
 *   node examples/bench/require_cost_sketch.js
 */
const path = require('path');
const { performance } = require('perf_hooks');

const FIX = path.join(__dirname, '_require_fixture');

function wipe() {
  for (const key of Object.keys(require.cache)) {
    if (key.startsWith(FIX)) delete require.cache[key];
  }
}

function timeLoad(entryRel, needHeavy) {
  wipe();
  const t0 = performance.now();
  const run = require(path.join(FIX, entryRel));
  const t1 = performance.now();
  run(needHeavy);
  const t2 = performance.now();
  return { loadMs: t1 - t0, callMs: t2 - t1, totalMs: t2 - t0 };
}

function median(xs) {
  const a = xs.slice().sort((x, y) => x - y);
  return a[Math.floor(a.length / 2)];
}

const ROUNDS = 21;
const eagerHappy = [];
const lazyHappy = [];
const eagerHeavy = [];
const lazyHeavy = [];

for (let i = 0; i < ROUNDS; i++) {
  eagerHappy.push(timeLoad('eager_entry.js', false).totalMs);
  lazyHappy.push(timeLoad('lazy_entry.js', false).totalMs);
  eagerHeavy.push(timeLoad('eager_entry.js', true).totalMs);
  lazyHeavy.push(timeLoad('lazy_entry.js', true).totalMs);
}

const row = (label, samples) =>
  `${label.padEnd(28)} median_total_ms=${median(samples).toFixed(3)}`;

console.log('require_cost_sketch (single-machine teaching numbers only)');
console.log(row('eager, happy path', eagerHappy));
console.log(row('lazy,  happy path', lazyHappy));
console.log(row('eager, needHeavy', eagerHeavy));
console.log(row('lazy,  needHeavy', lazyHeavy));
console.log('(expect: lazy happy << eager happy; lazy needHeavy ≈ eager needHeavy)');
