// String.indexOf in a hot decode: prefer a dense LUT over Map for short alphabets.
export function decode(chars: string, alphabet: string): number[] {
  const lut: number[] = new Array(256).fill(-1);
  for (let i = 0; i < alphabet.length; i++) {
    lut[alphabet.charCodeAt(i) & 0xff] = i;
  }
  const out: number[] = [];
  for (let i = 0; i < chars.length; i++) {
    out.push(lut[chars.charCodeAt(i) & 0xff]);
  }
  return out;
}
