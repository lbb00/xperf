export function clearFlag(obj: Record<string, unknown>, key: string) {
  delete obj[key];
}
