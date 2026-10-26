export function parseAll(raw: string[]): object[] {
  const out: object[] = [];
  for (const s of raw) {
    out.push(JSON.parse(s));
  }
  return out;
}

export function onHead(text: string, raw: string[]): void {
  for (const s of JSON.parse(text) as string[]) {
    raw.push(s);
  }
  raw.forEach((s) => JSON.parse(s));
}
