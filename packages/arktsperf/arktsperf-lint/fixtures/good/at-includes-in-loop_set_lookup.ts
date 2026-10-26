export function filterKnown(items: string[], known: string[]): string[] {
  const set = new Set(known);
  const out: string[] = [];
  for (let i = 0; i < items.length; i++) {
    if (set.has(items[i])) out.push(items[i]);
  }
  return out;
}
