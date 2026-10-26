export function filterKnown(items: string[], known: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < items.length; i++) {
    if (known.includes(items[i])) out.push(items[i]);
  }
  return out;
}

export function decode(chars: string, alphabet: string): number[] {
  const out: number[] = [];
  for (let i = 0; i < chars.length; i++) {
    out.push(alphabet.indexOf(chars[i]));
  }
  return out;
}
