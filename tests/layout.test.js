// The overview's layout: nothing may overlap or leave the area, whatever the windows.
// Run: node tests/layout.test.js   (tests/check.sh does)
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '../Layout.js');
const L = new Function(fs.readFileSync(file, 'utf8').replace(/^\.pragma library.*$/m, '') + '; return { arrange };')();

const big = { w: 3008, h: 1692 }, small = { w: 1728, h: 1117 };
const repeat = (n, f) => Array.from({ length: n }, (_, i) => f(i));
let seed = 7;
const rnd = (a, b) => { seed = (seed * 1103515245 + 12345) % 2147483648; return a + (seed / 2147483648) * (b - a); };
const cases = [
  ['one tiled', small, [{ x: 10, y: 39, w: 1708, h: 1068 }]],
  ['one small floating', small, [{ x: 214, y: 125, w: 782, h: 592 }]],
  ['two halves', small, [{ x: 10, y: 39, w: 849, h: 1068 }, { x: 869, y: 39, w: 849, h: 1068 }]],
  ['cascade of 7', big, repeat(7, i => ({ x: 300 + i * 24, y: 150 + i * 24, w: 1296, h: 893 }))],
  ['6 on the same spot', big, repeat(6, () => ({ x: 856, y: 400, w: 1296, h: 893 }))],
  ['8 overlapping browsers', big, [[1427, 180, 1392, 1208], [856, 413, 1268, 1125], [152, 645, 1672, 958], [513, 412, 1618, 1126],
    [1172, 103, 1550, 1250], [74, 180, 1349, 1165], [1621, 483, 1241, 1105], [238, 110, 930, 786]].map(([x, y, w, h]) => ({ x, y, w, h }))],
  ['20 random', big, repeat(20, () => ({ x: rnd(0, 2000), y: rnd(30, 900), w: rnd(400, 1500), h: rnd(300, 1000) }))],
  ['one taller than the area', small, [{ x: 0, y: 0, w: 600, h: 1117 }, { x: 300, y: 100, w: 900, h: 700 }]],
];

let failed = 0;
for (const [name, screen, frames] of cases) {
  const area = { x: 70, y: 172, w: screen.w - 140, h: screen.h - 172 - 60 };
  const t0 = process.hrtime.bigint();
  const slots = L.arrange(frames, { x: 0, y: 0, w: screen.w, h: screen.h }, area, 40, 1);
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  const problems = [];
  if (slots.length !== frames.length) problems.push('slot count');
  slots.forEach((a, i) => {
    const fa = frames[i];
    if (!(a.s > 0 && a.s <= 1.0001)) problems.push(`scale of ${i}: ${a.s}`);
    if (a.x < area.x - 1 || a.y < area.y - 1 || a.x + fa.w * a.s > area.x + area.w + 1 || a.y + fa.h * a.s > area.y + area.h + 1)
      problems.push(`${i} leaves the area`);
    for (let j = i + 1; j < slots.length; j++) {
      const b = slots[j], fb = frames[j];
      if (a.x < b.x + fb.w * b.s - 1 && b.x < a.x + fa.w * a.s - 1 && a.y < b.y + fb.h * b.s - 1 && b.y < a.y + fa.h * a.s - 1)
        problems.push(`${i} overlaps ${j}`);
    }
  });
  if (ms > 60) problems.push(`slow: ${ms.toFixed(0)} ms`);
  if (problems.length) failed++;
  console.log(`${problems.length ? 'FAIL' : 'ok  '} ${name}: scale ${slots[0].s.toFixed(3)}, ${ms.toFixed(1)} ms ${problems.slice(0, 3).join('; ')}`);
}
process.exit(failed ? 1 : 0);
