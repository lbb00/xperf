// Consistent field order vs divergent shapes (illustrative).
function makeGood(x, y) {
  return { x, y, z: 0 };
}

function makeBad(flag, x, y) {
  const o = {};
  if (flag) o.x = x;
  o.y = y;
  if (!flag) o.x = x;
  return o;
}

let s = 0;
for (let i = 0; i < 1000; i++) {
  s += makeGood(i, i).x;
  s += makeBad(i & 1, i, i).x;
}
console.log(s);
