export function parseAll(text: string, n: number): object[] {
  const out: object[] = [];
  for (let i = 0; i < n; i++) {
    out.push(JSON.parse(text));
  }
  return out;
}

export function dumpAll(obj: object, n: number): string[] {
  const out: string[] = [];
  for (let i = 0; i < n; i++) {
    out.push(JSON.stringify(obj));
  }
  return out;
}
