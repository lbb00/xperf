// Prefer batching over per-item await when the API allows (sketch only).
async function bad(items, fetchOne) {
  const out = [];
  for (const it of items) {
    out.push(await fetchOne(it));
  }
  return out;
}

async function better(items, fetchMany) {
  return fetchMany(items);
}

module.exports = { bad, better };
