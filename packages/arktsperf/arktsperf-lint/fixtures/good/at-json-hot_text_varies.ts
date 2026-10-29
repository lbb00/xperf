export function parseAll(raw: string[]): object[] {
  const out: object[] = [];
  for (const s of raw) {
    out.push(JSON.parse(s));
  }
  return out;
}
